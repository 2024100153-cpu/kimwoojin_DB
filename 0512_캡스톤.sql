-- 2026.05.05

CREATE TABLE `card_sets` (
  `set_id` int NOT NULL AUTO_INCREMENT,        -- 세트 고유 번호
  `set_code` varchar(10) NOT NULL,             -- 외부 API용 세트 코드 (예: SV1, SV4a)
  `series_name` varchar(50) DEFAULT NULL,      -- 상위 시리즈명, 없으면 NULL
  `set_name_ko` varchar(100) NOT NULL,         -- 한글 세트명
  `total_cards` int DEFAULT NULL,              -- 세트 내 전체 카드 수, 미확정이면 NULL
  `release_date` date DEFAULT NULL,            -- 국내 발매일, 미발매이면 NULL
  `logo_url` varchar(2048) DEFAULT NULL,       -- 세트 로고 이미지 URL
  PRIMARY KEY (`set_id`),
  UNIQUE KEY `set_code` (`set_code`)           -- 세트 코드 중복 삽입 방지
) ENGINE=InnoDB
  AUTO_INCREMENT=2
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;


CREATE TABLE `users` (
  `user_id` bigint NOT NULL AUTO_INCREMENT,    -- 회원 고유 번호
  `email` varchar(100) NOT NULL,              -- 로그인·알림용 이메일
  `login_id` varchar(50) NOT NULL,            -- 로그인 아이디
  `password_hash` varchar(255) NOT NULL,      -- 암호화된 비밀번호 해시값
  `nickname` varchar(50) NOT NULL,            -- 서비스 내 표시 닉네임
  `profile_img_url` varchar(2048) DEFAULT NULL, -- 프로필 이미지 URL, 미설정이면 NULL
  `tier` enum('BRONZE','SILVER','GOLD','DIAMOND') DEFAULT 'BRONZE', -- 회원 등급
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP, -- 계정 생성 일시
  PRIMARY KEY (`user_id`),
  UNIQUE KEY `email` (`email`),               -- 이메일 중복 방지
  UNIQUE KEY `nickname` (`nickname`),         -- 닉네임 중복 방지
  UNIQUE KEY `UKi3xs7wmfu2i3jt079uuetycit` (`login_id`) -- login_id 중복 방지
) ENGINE=InnoDB
  AUTO_INCREMENT=3
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;


CREATE TABLE `cards` (
  `card_id` bigint NOT NULL AUTO_INCREMENT,   -- 카드 고유 번호
  `set_id` int NOT NULL,                      -- 소속 세트, card_sets 참조
  `external_id` varchar(50) DEFAULT NULL,     -- 외부 API 카드 ID, 없으면 NULL
  `card_number` varchar(20) NOT NULL,         -- 세트 내 카드 번호 (예: 001/198)
  `card_name_ko` varchar(100) NOT NULL,       -- 한국어 카드명
  `rarity_code` varchar(10) DEFAULT NULL,     -- 희귀도 코드 (예: C, R, SR, UR)
  `attribute` varchar(10) DEFAULT NULL,       -- 카드 속성 (예: 불꽃, 물, 풀)
  `official_image_url` varchar(2048) DEFAULT NULL, -- 공식 카드 이미지 URL
  PRIMARY KEY (`card_id`),
  UNIQUE KEY `uq_set_card` (`set_id`, `card_number`), -- 세트 내 카드 번호 중복 방지
  UNIQUE KEY `external_id` (`external_id`),   -- 외부 API ID 중복 방지
  KEY `idx_card_name` (`card_name_ko`),       -- 카드명 검색 인덱스
  KEY `idx_rarity` (`rarity_code`),           -- 희귀도 필터 인덱스
  CONSTRAINT `cards_ibfk_1` FOREIGN KEY (`set_id`) REFERENCES `card_sets` (`set_id`) -- 세트 없으면 삽입 불가
) ENGINE=InnoDB
  AUTO_INCREMENT=4
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;


CREATE TABLE `user_collections` (
  `collection_id` bigint NOT NULL AUTO_INCREMENT, -- 컬렉션 항목 고유 번호
  `user_id` bigint NOT NULL,                  -- 카드 소유자, users 참조
  `card_id` bigint NOT NULL,                  -- 보유 카드, cards 참조
  `quantity` int DEFAULT '1',                 -- 보유 수량, 기본 1장
  `condition_grade` varchar(5) DEFAULT 'A',  -- 카드 컨디션 등급 (예: S, A, B, C)
  `acquired_method` varchar(20) DEFAULT NULL, -- 획득 경로 (예: PURCHASE, TRADE, PACK)
  `added_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP, -- 컬렉션 추가 일시
  PRIMARY KEY (`collection_id`),
  UNIQUE KEY `uq_user_card_condition` (`user_id`, `card_id`, `condition_grade`), -- 유저·카드·등급 조합 중복 방지
  KEY `card_id` (`card_id`),                  -- 카드별 보유 회원 조회 인덱스
  CONSTRAINT `user_collections_ibfk_1` FOREIGN KEY (`user_id`)
    REFERENCES `users` (`user_id`) ON DELETE CASCADE, -- 회원 탈퇴 시 컬렉션 자동 삭제
  CONSTRAINT `user_collections_ibfk_2` FOREIGN KEY (`card_id`)
    REFERENCES `cards` (`card_id`),           -- 컬렉션에 있는 카드는 삭제 불가
  CONSTRAINT `user_collections_chk_1` CHECK (`quantity` >= 0) -- 수량 음수 방지
) ENGINE=InnoDB
  AUTO_INCREMENT=3
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;


CREATE TABLE `marketplace_listings` (
  `listing_id` bigint NOT NULL AUTO_INCREMENT, -- 판매 게시글 고유 번호
  `seller_id` bigint NOT NULL,                -- 판매자, users 참조
  `collection_id` bigint DEFAULT NULL,        -- 판매자 컬렉션 항목, 삭제되면 NULL
  `card_id` bigint DEFAULT NULL,              -- 판매 카드, collection_id 삭제 시 보존용
  `price` int NOT NULL,                       -- 판매 희망 가격 (원 단위)
  `contact_info` varchar(100) NOT NULL,       -- 판매자 연락처
  `location` varchar(255) NOT NULL,           -- 직거래 희망 지역
  `status` enum('판매중','예약중','판매완료','취소됨') DEFAULT '판매중', -- 판매 상태
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP, -- 게시글 등록 일시
  `sold_at` timestamp NULL DEFAULT NULL,      -- 거래 완료 일시, 완료 전이면 NULL
  PRIMARY KEY (`listing_id`),
  KEY `seller_id` (`seller_id`),              -- 판매자별 게시글 조회 인덱스
  KEY `collection_id` (`collection_id`),      -- 컬렉션 기반 조회 인덱스
  KEY `idx_location` (`location`),            -- 지역별 검색 인덱스
  KEY `idx_status` (`status`),               -- 상태별 필터 인덱스
  KEY `idx_card_id` (`card_id`),              -- 카드별 조회 인덱스
  CONSTRAINT `marketplace_listings_ibfk_1` FOREIGN KEY (`seller_id`)
    REFERENCES `users` (`user_id`),           -- 판매글 있는 판매자는 삭제 불가
  CONSTRAINT `marketplace_listings_ibfk_2` FOREIGN KEY (`collection_id`)
    REFERENCES `user_collections` (`collection_id`) ON DELETE SET NULL, -- 컬렉션 삭제 시 NULL
  CONSTRAINT `marketplace_listings_ibfk_3` FOREIGN KEY (`card_id`)
    REFERENCES `cards` (`card_id`)            -- 판매글에 등록된 카드는 삭제 불가
) ENGINE=InnoDB
  AUTO_INCREMENT=3
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;


CREATE TABLE `trade_history` (
  `history_id` bigint NOT NULL AUTO_INCREMENT, -- 거래 이력 고유 번호
  `buyer_id` bigint DEFAULT NULL,             -- 구매자, 탈퇴 시 NULL
  `seller_id` bigint DEFAULT NULL,            -- 판매자, 탈퇴 시 NULL
  `card_id` bigint NOT NULL,                  -- 거래된 카드, cards 참조
  `final_price` int NOT NULL,                 -- 실제 거래 체결 금액 (원 단위)
  `trade_date` timestamp NULL DEFAULT CURRENT_TIMESTAMP, -- 거래 체결 일시
  PRIMARY KEY (`history_id`),
  KEY `buyer_id` (`buyer_id`),                -- 구매자별 거래 내역 조회 인덱스
  KEY `seller_id` (`seller_id`),              -- 판매자별 거래 내역 조회 인덱스
  KEY `card_id` (`card_id`),                  -- 카드별 거래 이력 조회 인덱스
  KEY `idx_card_trade_date` (`card_id`, `trade_date`), -- 카드별 최근 거래가 조회 인덱스
  CONSTRAINT `trade_history_ibfk_1` FOREIGN KEY (`buyer_id`)
    REFERENCES `users` (`user_id`) ON DELETE SET NULL, -- 구매자 탈퇴 시 NULL, 이력 보존
  CONSTRAINT `trade_history_ibfk_2` FOREIGN KEY (`seller_id`)
    REFERENCES `users` (`user_id`) ON DELETE SET NULL, -- 판매자 탈퇴 시 NULL, 이력 보존
  CONSTRAINT `trade_history_ibfk_3` FOREIGN KEY (`card_id`)
    REFERENCES `cards` (`card_id`)            -- 거래 이력 있는 카드는 삭제 불가
) ENGINE=InnoDB
  AUTO_INCREMENT=1
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;

SET GLOBAL event_scheduler = ON; -- 이벤트 스케줄러 활성화
CREATE EVENT IF NOT EXISTS archive_old_trades
  ON SCHEDULE EVERY 1 WEEK       -- 매주 1회 실행
  COMMENT '5년 이상 된 거래 내역 자동 삭제'
  DO DELETE FROM trade_history WHERE trade_date < DATE_SUB(NOW(), INTERVAL 5 YEAR);


-- ========================================================================================== 0512 추가 ========================================================================================== --
-- 2026.05.12

-- 1. set_code 길이 확장 (varchar 10 → 20)
ALTER TABLE `card_sets`
  MODIFY COLUMN `set_code` varchar(20) NOT NULL; -- 외부 API 코드 길이 대비 확장
-- 2. cards - attribute 길이 확장 (varchar 10 → 20)
ALTER TABLE `cards`
  MODIFY COLUMN `attribute` varchar(20) DEFAULT NULL; -- 속성값 길이 대비 확장
-- 3. marketplace_listings - card_id 컬럼 순서 이동
ALTER TABLE `marketplace_listings`
  MODIFY COLUMN `card_id` bigint DEFAULT NULL AFTER `collection_id`; -- collection_id 바로 뒤로 이동
-- 4. users - login_id 확장, tier varchar 변경, CHECK 추가
-- login_id 인덱스는 백업 DB에 이미 존재하니 생략함
ALTER TABLE `users`
  MODIFY COLUMN `login_id` varchar(100) NOT NULL,      -- login_id 길이 확장 (50 → 100)
  MODIFY COLUMN `tier` varchar(20) DEFAULT 'BRONZE';   -- enum → varchar 변경 (JPA 호환)
ALTER TABLE `users`
  ADD CONSTRAINT `chk_tier` CHECK (tier IN ('BRONZE','SILVER','GOLD','DIAMOND')); -- tier 유효값 제한
-- 5. 가격 유효성 검사 추가
ALTER TABLE `marketplace_listings`
  ADD CONSTRAINT `chk_price` CHECK (price > 0);         -- 판매가 음수 방지
ALTER TABLE `trade_history`
  ADD CONSTRAINT `chk_final_price` CHECK (final_price > 0); -- 거래가 음수 방지
-- 6. 신규 테이블: marketplace_favorite (즐겨찾기)
CREATE TABLE IF NOT EXISTS `marketplace_favorite` (
  `favorite_id` bigint NOT NULL AUTO_INCREMENT, -- 즐겨찾기 고유 번호
  `user_id` bigint NOT NULL,                    -- 사용자 ID (FK)
  `listing_id` bigint NOT NULL,                 -- 판매글 ID (FK)
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP, -- 즐겨찾기 등록 일시
  PRIMARY KEY (`favorite_id`),
  UNIQUE KEY `uq_user_listing` (`user_id`, `listing_id`), -- 같은 판매글 중복 즐겨찾기 방지
  CONSTRAINT `fk_fav_user_id` FOREIGN KEY (`user_id`)
    REFERENCES `users` (`user_id`) ON DELETE CASCADE,   -- 회원 탈퇴 시 즐겨찾기 자동 삭제
  CONSTRAINT `fk_fav_listing_id` FOREIGN KEY (`listing_id`)
    REFERENCES `marketplace_listings` (`listing_id`) ON DELETE CASCADE -- 판매글 삭제 시 즐겨찾기 자동 삭제
) ENGINE=InnoDB
  AUTO_INCREMENT=1
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;
-- 7. 신규 테이블: marketplace_image (판매글 이미지)
CREATE TABLE IF NOT EXISTS `marketplace_image` (
  `image_id` bigint NOT NULL AUTO_INCREMENT,    -- 이미지 고유 번호
  `listing_id` bigint NOT NULL,                 -- 연관 판매글 ID (FK)
  `image_path` varchar(2048) NOT NULL,          -- 이미지 저장 경로
  PRIMARY KEY (`image_id`),
  KEY `idx_image_listing` (`listing_id`),       -- 판매글별 이미지 조회 인덱스
  CONSTRAINT `fk_marketplace_listing` FOREIGN KEY (`listing_id`)
    REFERENCES `marketplace_listings` (`listing_id`) ON DELETE CASCADE -- 판매글 삭제 시 이미지 자동 삭제
) ENGINE=InnoDB
  AUTO_INCREMENT=1
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;
-- 8. Collate 통일 및 컬럼 보완 (백업 DB 기준)
ALTER TABLE `marketplace_favorite`
  CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci; -- 기존 테이블과 Collate 통일
ALTER TABLE `marketplace_image`
  MODIFY COLUMN `image_path` varchar(2048) NOT NULL,            -- URL 길이 대비 확장
  CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci; -- 기존 테이블과 Collate 통일
  -- ========================================================================================== 까지 0512 ========================================================================================== --