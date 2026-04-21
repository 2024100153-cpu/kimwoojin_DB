/*
============================================================
[1. 카드 세트 테이블]
핵심: 기준 데이터(Master Data)의 관리. 
변경이 적고 참조가 빈번하므로 정규화의 출발점이 됨.
============================================================
*/
CREATE TABLE IF NOT EXISTS card_sets (
    set_id INT AUTO_INCREMENT PRIMARY KEY,        -- 내부 조인 속도 향상을 위한 정수형 식별자
    set_code VARCHAR(20) NOT NULL UNIQUE,          -- SV4a 처럼 대외적으로 쓰이는 고유 코드 (비즈니스 키)
    series_name VARCHAR(50),                       -- '스칼렛&바이올렛' 등 대분류를 통한 그룹화 목적
    set_name_ko VARCHAR(100) NOT NULL,             -- 사용자에게 보여줄 한글 공식 명칭
    total_cards INT,                               -- 수집률 계산(보유량/전체)을 위한 기준값
    release_date DATE,                             -- 신규 세트 순서대로 정렬하기 위한 날짜 데이터
    logo_url VARCHAR(2048)                         -- UI에서 세트 아이콘을 렌더링하기 위한 경로
) ENGINE=InnoDB; -- 트랜잭션 지원 및 행 단위 잠금을 위한 스토리지 엔진

/*
============================================================
[2. 유저 정보 테이블]
핵심: 보안과 식별. 개인정보 보호를 위한 최소한의 설계.
============================================================
*/
CREATE TABLE IF NOT EXISTS users (
    user_id BIGINT AUTO_INCREMENT PRIMARY KEY,    -- 확장성을 고려하여 8바이트 큰 정수(BIGINT) 사용
    email VARCHAR(100) NOT NULL UNIQUE,            -- 로그인 ID 역할 및 고유성 보장
    password_hash VARCHAR(255) NOT NULL,           -- 단방향 암호화(BCrypt 등)된 값을 담기 위한 충분한 길이
    nickname VARCHAR(50) NOT NULL UNIQUE,          -- 서비스 내 활동명, 중복 방지로 식별성 확보
    profile_img_url VARCHAR(2048),                 -- 유저 커스터마이징 이미지
    tier VARCHAR(20) DEFAULT 'BRONZE',             -- 게이미피케이션 요소 (수집 등급)
    last_login_at TIMESTAMP NULL,                  -- 휴면 계정 판단 및 보안 모니터링용
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP -- 유저 가입 시점 기록
) ENGINE=InnoDB;

/*
============================================================
[3. 인증 토큰 테이블]
핵심: 세션 관리의 분리. 유저 테이블 부하 감소 및 멀티 디바이스 대응.
============================================================
*/
CREATE TABLE IF NOT EXISTS user_auth_tokens (
    token_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,                       -- 유저 테이블과의 1:N 관계 (한 유저가 여러 기기 로그인 가능)
    refresh_token VARCHAR(512) NOT NULL,           -- JWT나 고유 토큰값 저장
    device_info VARCHAR(255),                      -- "어디서 로그인했나?" 정보 제공 (보안 알림용)
    ip_address VARCHAR(45),                        -- 이상 로그인 감지 및 추적용
    expires_at TIMESTAMP NOT NULL,                 -- 만료된 토큰을 서버가 거부하기 위한 기준
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, 
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE, -- 탈퇴 시 토큰 자동 삭제(고립 데이터 방지)
    INDEX idx_refresh_token (refresh_token)        -- 검증 시 빠른 조회를 위한 필수 인덱스
) ENGINE=InnoDB;

/*
============================================================
[4. 카드 상세 정보 테이블]
핵심: 대량의 데이터 조회 최적화.
============================================================
*/
CREATE TABLE IF NOT EXISTS cards (
    card_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    set_id INT NOT NULL,                           -- 어떤 세트에 포함된 카드인지 연결
    external_id VARCHAR(50) UNIQUE,                -- 외부 API 연동 시 사용할 외부 고유 ID
    card_number VARCHAR(20) NOT NULL,              -- 세트 내 번호 (예: 001/190)
    card_name_ko VARCHAR(100) NOT NULL,            -- 검색의 핵심 키워드
    rarity_code VARCHAR(10),                       -- RR, SAR 등 희귀도 분류
    attribute VARCHAR(20),                         -- 풀, 불, 물 등 속성 필터링용
    official_image_url VARCHAR(2048),              -- 카드 이미지 경로
    FOREIGN KEY (set_id) REFERENCES card_sets(set_id),
    UNIQUE KEY uq_set_card (set_id, card_number),  -- 한 세트 내에 동일 번호가 중복될 수 없는 도메인 규칙 적용
    INDEX idx_card_name (card_name_ko)             -- 카드 이름으로 검색할 때 성능을 극대화
) ENGINE=InnoDB;

/*
============================================================
[5. 유저 보유 카드 테이블 (도감)]
핵심: 다대다(N:M) 관계 해소 및 자산 관리.
============================================================
*/
CREATE TABLE IF NOT EXISTS user_collections (
    collection_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,                       -- 누구의 소유인가
    card_id BIGINT NOT NULL,                       -- 어떤 카드인가
    quantity INT DEFAULT 1 CHECK (quantity >= 0),  -- 보유 수량 (음수 방지 제약조건)
    condition_grade VARCHAR(5) DEFAULT 'A',        -- S, A, B 등 상태에 따른 가치 구분
    acquired_method VARCHAR(20),                   -- 팩 개봉, 거래 등 획득 경로
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,  -- 수집 시점
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (card_id) REFERENCES cards(card_id),
    -- [중요] 유저+카드+상태가 같으면 레코드를 합치고, 다르면 별도로 관리하도록 보장
    UNIQUE KEY uq_user_card_condition (user_id, card_id, condition_grade)
) ENGINE=InnoDB;

/*
============================================================
[6. 판매 정보 테이블 (마켓플레이스)]
핵심: 거래 상태 추적 및 유효성 관리.
============================================================
*/
CREATE TABLE IF NOT EXISTS marketplace_listings (
    listing_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    seller_id BIGINT NOT NULL,                     -- 판매자 식별
    collection_id BIGINT,                          -- 내 도감의 어떤 물건을 내놓았는지 연결
    price INT NOT NULL,                            -- 판매 희망 가격
    contact_info VARCHAR(100) NOT NULL,            -- 오픈채팅 등 연락처
    location VARCHAR(255) NOT NULL,                -- 직거래 장소
    status ENUM('판매중', '예약중', '판매완료', '취소됨') DEFAULT '판매중', -- 상태를 제한하여 비즈니스 로직 단순화
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    sold_at TIMESTAMP NULL,                        -- 거래 완료 시점 (통계용)
    FOREIGN KEY (seller_id) REFERENCES users(user_id),
    FOREIGN KEY (collection_id) REFERENCES user_collections(collection_id) ON DELETE SET NULL, -- 내 도감에서 지워져도 게시글 정보는 유지
    INDEX idx_location (location),                 -- 동네 기반 검색 최적화
    INDEX idx_status (status)                      -- '판매중'인 것만 골라낼 때 성능 향상
) ENGINE=InnoDB;

/*
============================================================
[7. 거래 내역 테이블 (영수증)]
핵심: 데이터 휘발 방지 및 감사(Audit) 로그.
============================================================
*/
CREATE TABLE IF NOT EXISTS trade_history (
    history_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    buyer_id BIGINT,                               -- 구매자 (탈퇴 시 NULL 처리하여 통계 유지)
    seller_id BIGINT,                              -- 판매자 (탈퇴 시 NULL 처리)
    card_id BIGINT NOT NULL,                       -- 거래된 물건 정보
    final_price INT NOT NULL,                      -- 실제 낙찰가
    trade_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (buyer_id) REFERENCES users(user_id) ON DELETE SET NULL,
    FOREIGN KEY (seller_id) REFERENCES users(user_id) ON DELETE SET NULL,
    FOREIGN KEY (card_id) REFERENCES cards(card_id)
) ENGINE=InnoDB;