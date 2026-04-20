-- 1. 카드 세트 테이블: 발매 시리즈의 메타 데이터를 저장하는 기준 테이블
CREATE TABLE IF NOT EXISTS card_sets (
    set_id INT AUTO_INCREMENT PRIMARY KEY,        -- 내부 관리용 고유 번호
    set_code VARCHAR(20) NOT NULL UNIQUE,         -- 세트 식별 코드 (예: SV4a)
    series_name VARCHAR(50),                      -- 시리즈 분류 (예: 스칼렛&바이올렛)
    set_name_ko VARCHAR(100) NOT NULL,            -- 한국어 공식 명칭
    total_cards INT,                              -- 세트 전체 카드 장수
    release_date DATE,                            -- 발매일
    logo_url VARCHAR(2048)                        -- 세트 로고 URL (S3 등 이미지 주소)
) ENGINE=InnoDB;                                  -- 트랜잭션을 지원하는 InnoDB 엔진 명시

-- 2. 카드 상세 정보 테이블: 세상의 모든 포켓몬 카드 마스터 데이터
CREATE TABLE IF NOT EXISTS cards (
    card_id BIGINT AUTO_INCREMENT PRIMARY KEY,    -- 카드 고유 번호
    set_id INT NOT NULL,                          -- 소속 세트 ID (FK)
    external_id VARCHAR(50) UNIQUE,               -- 외부 시세 API와 연동하기 위한 식별자
    card_number VARCHAR(20) NOT NULL,             -- 카드 실물 일련번호 (예: 001/190)
    card_name_ko VARCHAR(100) NOT NULL,           -- 카드 한글명
    rarity_code VARCHAR(10),                      -- 레어도 (SAR, SR 등)
    attribute VARCHAR(20),                        -- 속성 (불, 물 등)
    official_image_url VARCHAR(2048),             -- 공식 이미지 링크
    FOREIGN KEY (set_id) REFERENCES card_sets(set_id), -- 세트가 삭제/수정될 때 연동
    UNIQUE KEY uq_set_card (set_id, card_number), -- 한 세트 안에 똑같은 번호가 중복되는 것 방지
    INDEX idx_card_name (card_name_ko)             -- 유저들이 이름으로 검색할 때 속도 향상
) ENGINE=InnoDB;

-- 3. 유저 정보 테이블: 서비스 사용자 계정 데이터
CREATE TABLE IF NOT EXISTS users (
    user_id BIGINT AUTO_INCREMENT PRIMARY KEY,    -- 유저 고유 번호
    email VARCHAR(100) NOT NULL UNIQUE,           -- 이메일 (로그인 ID)
    password_hash VARCHAR(255) NOT NULL,          -- 비밀번호 해시값 (암호화 저장)
    nickname VARCHAR(50) NOT NULL UNIQUE,         -- 서비스 닉네임
    profile_img_url VARCHAR(2048),                -- 프로필 사진 경로
    tier VARCHAR(20) DEFAULT 'BRONZE',            -- 수집 활동량에 따른 등급
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP -- 가입일시
) ENGINE=InnoDB;

-- 4. 유저 보유 카드 테이블: 실시간 수량(Quantity) 관리형 도감
CREATE TABLE IF NOT EXISTS user_collections (
    collection_id BIGINT AUTO_INCREMENT PRIMARY KEY, -- 보유 건당 고유 번호
    user_id BIGINT NOT NULL,                      -- 소유자 ID (FK)
    card_id BIGINT NOT NULL,                      -- 카드 ID (FK)
    quantity INT DEFAULT 1 CHECK (quantity >= 0), -- 보유 수량 (0 미만으로 내려가면 에러 발생)
    condition_grade VARCHAR(5) DEFAULT 'A',        -- 카드 보관 상태 (S, A, B 등)
    acquired_method VARCHAR(20),                  -- 획득 경로 (거래, 뽑기 등)
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, -- 최초 등록일
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE, -- 유저 탈퇴 시 도감 자동 삭제
    FOREIGN KEY (card_id) REFERENCES cards(card_id),
    -- [중요] 한 유저가 같은 카드&같은 상태를 중복 등록하면 로우를 새로 안 만들고 수량만 더함
    UNIQUE KEY uq_user_card_condition (user_id, card_id, condition_grade)
) ENGINE=InnoDB;

-- 5. 판매 정보 테이블: 장터에 올라온 판매 게시글
CREATE TABLE IF NOT EXISTS marketplace_listings (
    listing_id BIGINT AUTO_INCREMENT PRIMARY KEY, -- 판매글 고유 번호
    seller_id BIGINT NOT NULL,                    -- 판매자 ID (FK)
    collection_id BIGINT,                         -- 판매 중인 내 도감 아이템 번호 (NULL 가능)
    price INT NOT NULL,                           -- 판매 희망 가격
    contact_info VARCHAR(100) NOT NULL,           -- 구매자 연락 수단
    location VARCHAR(255) NOT NULL,               -- 직거래 장소
    status ENUM('판매중', '예약중', '판매완료', '취소됨') DEFAULT '판매중', -- 판매 진행 상태
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, -- 게시글 작성일
    sold_at TIMESTAMP NULL,                       -- 판매 완료 확정 시각
    FOREIGN KEY (seller_id) REFERENCES users(user_id),
    -- [중요] 내 도감에서 삭제(ON DELETE)되어도 판매글 이력은 보존(SET NULL)하여 통계에 활용
    FOREIGN KEY (collection_id) REFERENCES user_collections(collection_id) ON DELETE SET NULL,
    INDEX idx_location (location),                 -- 동네별 검색 최적화
    INDEX idx_status (status)                      -- 판매 중인 글만 필터링할 때 속도 향상
) ENGINE=InnoDB;

-- 6. 거래 내역 테이블: 최종 거래 완료된 영수증 보존함
CREATE TABLE IF NOT EXISTS trade_history (
    history_id BIGINT AUTO_INCREMENT PRIMARY KEY, -- 영수증 고유 번호
    buyer_id BIGINT,                              -- 구매자 ID (유저 삭제 시 NULL로 보존)
    seller_id BIGINT,                             -- 판매자 ID (유저 삭제 시 NULL로 보존)
    card_id BIGINT NOT NULL,                      -- 거래된 카드 번호 (FK)
    final_price INT NOT NULL,                     -- 최종 체결 가격
    trade_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP, -- 거래 체결 일시
    FOREIGN KEY (buyer_id) REFERENCES users(user_id) ON DELETE SET NULL,
    FOREIGN KEY (seller_id) REFERENCES users(user_id) ON DELETE SET NULL,
    FOREIGN KEY (card_id) REFERENCES cards(card_id)
) ENGINE=InnoDB;
/*
[거래 시뮬레이션 및 백엔드 연동 가이드]
   
   1. SQL 시뮬레이션 방법:
      - 아래의 SET 문에서 아이디 숫자를 직접 수정한 뒤, 전체 쿼리를 드래그해서 실행함
      
   2. 백엔드(Node.js/Python/Java 등) 연동 원리:
      - 실제 앱에서는 아래의 SET @target_... 문장을 쓰지 않음
      - 대신 쿼리문의 변수 자리에 '?'(물음표)를 넣고, 백엔드에서 실제 값을 주입
      - 이를 'Prepared Statement'라고 하며, 보안(SQL Injection 방지)을 위한 필수 절차임
*/
-- 시뮬레이션을 위한 가상 데이터 설정
SET @target_buyer = 1;      -- 구매 버튼을 누른 사람의 ID
SET @target_listing = 10;   -- 지금 구매하려는 장터 게시글 번호
/*
[백엔드 구현 예시 코드 - Node.js (mysql2 기준)]
   
   // 클라이언트로부터 요청이 들어왔을 때 실행되는 함수 내부라고 가정함
   const buyerId = req.user.id;         // 로그인 유저 ID
   const listingId = req.body.listingId; // 클릭한 판매글 ID

   // 1단계 선점 쿼리 예시 (변수 대신 '?' 사용)
   const sql1 = "UPDATE marketplace_listings SET status = '판매완료', sold_at = NOW() WHERE listing_id = ? AND status = '판매중'";
   
   // 실행 시 배열 안에 실제 데이터를 순서대로 넣어주면 됨
   db.query(sql1, [listingId], (err, result) => {
       if (result.affectedRows === 0) {
           return res.status(400).send("이미 판매되었거나 존재하지 않는 게시글입니다.");
       }
       // 이후 단계들(영수증 기록, 재고 이동 등)도 순차적으로 진행...
   });
*/
-- [트랜잭션 시작] 모든 쿼리가 성공하거나, 아니면 아예 다 취소되거나 (All or Nothing)
START TRANSACTION;

-- 1단계: 판매글 선점 (가장 중요!)
-- 상태를 '판매완료'로 바꾸되, '판매중'인 글일 때만 업데이트함. 
-- 동시에 여러 명이 눌러도 가장 먼저 도착한 쿼리 하나만 성공함.
UPDATE marketplace_listings 
SET status = '판매완료', sold_at = NOW() 
WHERE listing_id = @target_listing AND status = '판매중';

-- 2단계: 거래 기록 생성
-- 1단계에서 성공했을 때만 데이터가 넘어오며 영수증을 작성함.
INSERT INTO trade_history (buyer_id, seller_id, card_id, final_price)
SELECT @target_buyer, m.seller_id, uc.card_id, m.price
FROM marketplace_listings AS m
JOIN user_collections AS uc ON m.collection_id = uc.collection_id
WHERE m.listing_id = @target_listing AND m.status = '판매완료';

-- 3단계: 구매자의 도감에 카드 추가
-- 만약 이미 같은 카드를 가지고 있다면 수량(quantity)만 1 증가시키고, 없으면 새로 한 줄 만듦.
INSERT INTO user_collections (user_id, card_id, quantity, condition_grade, acquired_method)
SELECT @target_buyer, uc.card_id, 1, uc.condition_grade, 'TRADE'
FROM marketplace_listings AS m
JOIN user_collections AS uc ON m.collection_id = uc.collection_id
WHERE m.listing_id = @target_listing
ON DUPLICATE KEY UPDATE quantity = quantity + 1;

-- 4단계: 판매자의 도감에서 수량 차감
-- 판매자의 카드 장수를 1 줄임. (단, 수량이 0보다 클 때만 수행하여 오류 방지)
UPDATE user_collections uc
JOIN marketplace_listings m ON uc.collection_id = m.collection_id
SET uc.quantity = uc.quantity - 1
WHERE m.listing_id = @target_listing AND uc.quantity > 0;

-- 5단계: 최종 확정
-- 여기까지 에러 없이 왔다면 DB에 영구 반영함.
COMMIT;

-- 가상 뷰(View) 생성: 수량이 1장 이상인 진짜 '보유 카드'만 모아서 보여줌
-- (수량이 0인 데이터는 도감 화면에서 자동으로 걸러줌)
CREATE OR REPLACE VIEW active_user_collections AS
SELECT * FROM user_collections WHERE quantity > 0;

-- 이벤트 스케줄러 활성화: 예약된 자동 작업 기능을 켬
SET GLOBAL event_scheduler = ON;

-- 정기 데이터 정리: 거래 내역이 너무 쌓이면 검색이 느려지므로 6개월 지난 영수증은 자동 삭제
CREATE EVENT IF NOT EXISTS archive_old_trades
ON SCHEDULE EVERY 1 WEEK -- 매주 1번씩 실행
COMMENT '매주 월요일, 6개월 이상 된 거래 내역 정리로 DB 최적화'
DO
  DELETE FROM trade_history 
  WHERE trade_date < DATE_SUB(NOW(), INTERVAL 6 MONTH);