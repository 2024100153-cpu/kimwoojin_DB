-- 2026.05.05 작성
CREATE TABLE `card_sets` (
  `set_id` int NOT NULL AUTO_INCREMENT, -- 세트 고유 번호, 자동 증가
  `set_code` varchar(10) NOT NULL, -- 외부 API용 세트 식별 코드 (예: SV1, SV4a)
  `series_name` varchar(50) DEFAULT NULL, -- 상위 시리즈명 (예: 스칼렛&바이올렛), 없으면 NULL
  `set_name_ko` varchar(100) NOT NULL, -- 화면에 보여줄 한글 세트명
  `total_cards` int DEFAULT NULL, -- 세트 내 전체 카드 수, 미확정이면 NULL
  `release_date` date DEFAULT NULL, -- 국내 발매일, 미발매이면 NULL
  `logo_url` varchar(2048) DEFAULT NULL, -- 세트 로고 이미지 URL
  PRIMARY KEY (`set_id`), -- set_id를 기본키로 사용
  UNIQUE KEY `set_code` (`set_code`) -- 같은 세트 코드 중복 삽입 방지
) ENGINE=InnoDB -- 트랜잭션·FK 지원 스토리지 엔진
  AUTO_INCREMENT=2 -- 다음 삽입될 set_id 시작값
  DEFAULT CHARSET=utf8mb4 -- 한글·이모지 저장 가능한 문자셋
  COLLATE=utf8mb4_0900_ai_ci; -- 대소문자 구분 없는 정렬 규칙


CREATE TABLE `users` (
  `user_id` bigint NOT NULL AUTO_INCREMENT, -- 회원 고유 번호, 자동 증가
  `email` varchar(100) NOT NULL, -- 로그인·알림용 이메일, 중복 불가
  `login_id` varchar(50) NOT NULL, -- 로그인 아이디, 이메일과 별개로 운영
  `password_hash` varchar(255) NOT NULL, -- bcrypt 등으로 암호화된 비밀번호 해시값
  `nickname` varchar(50) NOT NULL, -- 서비스 내 표시 닉네임, 중복 불가
  `profile_img_url` varchar(2048) DEFAULT NULL, -- 프로필 이미지 URL, 미설정이면 NULL
  `tier` enum('BRONZE','SILVER','GOLD','DIAMOND') DEFAULT 'BRONZE', -- 회원 등급, 가입 시 BRONZE 자동 부여
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP, -- 계정 생성 일시, 자동 기록
  PRIMARY KEY (`user_id`), -- user_id를 기본키로 사용
  UNIQUE KEY `email` (`email`), -- 이메일 중복 방지
  UNIQUE KEY `nickname` (`nickname`), -- 닉네임 중복 방지
  UNIQUE KEY `UKi3xs7wmfu2i3jt079uuetycit` (`login_id`) -- login_id 중복 방지 (JPA 생성 키명)
) ENGINE=InnoDB
  AUTO_INCREMENT=3
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;


CREATE TABLE `cards` (
  `card_id` bigint NOT NULL AUTO_INCREMENT, -- 카드 고유 번호, 자동 증가
  `set_id` int NOT NULL, -- 소속 세트 번호, card_sets 참조
  `external_id` varchar(50) DEFAULT NULL, -- 외부 API에서 부여한 카드 ID, 없으면 NULL
  `card_number` varchar(20) NOT NULL, -- 세트 내 카드 번호 (예: 001/198)
  `card_name_ko` varchar(100) NOT NULL, -- 한국어 카드명, 검색에 사용
  `rarity_code` varchar(10) DEFAULT NULL, -- 희귀도 코드 (예: C, R, SR, UR)
  `attribute` varchar(10) DEFAULT NULL, -- 카드 속성 (예: 불꽃, 물, 풀)
  `official_image_url` varchar(2048) DEFAULT NULL, -- 공식 카드 이미지 URL
  PRIMARY KEY (`card_id`), -- card_id를 기본키로 사용
  UNIQUE KEY `uq_set_card` (`set_id`, `card_number`), -- 같은 세트 내 카드 번호 중복 방지
  UNIQUE KEY `external_id` (`external_id`), -- 외부 API ID 중복 방지
  KEY `idx_card_name` (`card_name_ko`), -- 카드명 검색 속도 향상
  KEY `idx_rarity` (`rarity_code`), -- 희귀도 필터 검색 속도 향상
  CONSTRAINT `cards_ibfk_1` FOREIGN KEY (`set_id`) REFERENCES `card_sets` (`set_id`) -- set_id → card_sets 참조, 세트 없으면 삽입 불가
) ENGINE=InnoDB
  AUTO_INCREMENT=4
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;


CREATE TABLE `user_collections` (
  `collection_id` bigint NOT NULL AUTO_INCREMENT, -- 컬렉션 항목 고유 번호, 자동 증가
  `user_id` bigint NOT NULL, -- 카드 소유자, users 참조
  `card_id` bigint NOT NULL, -- 보유 카드, cards 참조
  `quantity` int DEFAULT '1', -- 보유 수량, 기본 1장
  `condition_grade` varchar(5) DEFAULT 'A', -- 카드 컨디션 등급 (예: S, A, B, C)
  `acquired_method` varchar(20) DEFAULT NULL, -- 획득 경로 (예: PURCHASE, TRADE, PACK)
  `added_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP, -- 컬렉션 추가 일시, 자동 기록
  PRIMARY KEY (`collection_id`), -- collection_id를 기본키로 사용
  UNIQUE KEY `uq_user_card_condition` (`user_id`, `card_id`, `condition_grade`), -- 같은 유저·카드·등급 조합 중복 방지
  KEY `card_id` (`card_id`), -- 특정 카드 보유 회원 조회 속도 향상
  CONSTRAINT `user_collections_ibfk_1` FOREIGN KEY (`user_id`)
    REFERENCES `users` (`user_id`) ON DELETE CASCADE, -- 회원 탈퇴 시 컬렉션 전체 자동 삭제
  CONSTRAINT `user_collections_ibfk_2` FOREIGN KEY (`card_id`)
    REFERENCES `cards` (`card_id`), -- 컬렉션에 있는 카드는 삭제 불가
  CONSTRAINT `user_collections_chk_1` CHECK (`quantity` >= 0) -- 수량 음수 방지
) ENGINE=InnoDB
  AUTO_INCREMENT=3
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;


CREATE TABLE `marketplace_listings` (
  `listing_id` bigint NOT NULL AUTO_INCREMENT, -- 판매 게시글 고유 번호, 자동 증가
  `seller_id` bigint NOT NULL, -- 판매자, users 참조
  `collection_id` bigint DEFAULT NULL, -- 판매자 컬렉션 항목, 삭제되면 NULL로 변경
  `price` int NOT NULL, -- 판매 희망 가격 (원 단위)
  `contact_info` varchar(100) NOT NULL, -- 판매자 연락처 (전화번호, 오픈채팅 등)
  `location` varchar(255) NOT NULL, -- 직거래 희망 지역
  `status` enum('판매중','예약중','판매완료','취소됨') DEFAULT '판매중', -- 판매 상태, 등록 직후 판매중 자동 설정
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP, -- 게시글 등록 일시, 자동 기록
  `sold_at` timestamp NULL DEFAULT NULL, -- 거래 완료 일시, 완료 전이면 NULL
  `card_id` bigint DEFAULT NULL, -- 판매 카드, cards 참조 (collection_id 삭제돼도 카드 정보 보존용)
  PRIMARY KEY (`listing_id`), -- listing_id를 기본키로 사용
  KEY `seller_id` (`seller_id`), -- 특정 판매자 게시글 조회 속도 향상
  KEY `collection_id` (`collection_id`), -- 컬렉션 기반 조회 속도 향상
  KEY `idx_location` (`location`), -- 지역별 검색 속도 향상
  KEY `idx_status` (`status`), -- 상태별 필터링 속도 향상
  KEY `idx_card_id` (`card_id`), -- card_id 조회 속도 향상
  KEY `idx_status_created` (`status`, `created_at`), -- 판매중+최신순 조회 속도 향상
  CONSTRAINT `marketplace_listings_ibfk_1` FOREIGN KEY (`seller_id`)
    REFERENCES `users` (`user_id`), -- 판매글 있는 판매자는 삭제 불가
  CONSTRAINT `marketplace_listings_ibfk_2` FOREIGN KEY (`collection_id`)
    REFERENCES `user_collections` (`collection_id`) ON DELETE SET NULL, -- 컬렉션 삭제 시 NULL로 변경
  CONSTRAINT `marketplace_listings_ibfk_3` FOREIGN KEY (`card_id`)
    REFERENCES `cards` (`card_id`) -- 판매글에 등록된 카드는 삭제 불가
) ENGINE=InnoDB
  AUTO_INCREMENT=3
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;


CREATE TABLE `trade_history` (
  `history_id` bigint NOT NULL AUTO_INCREMENT, -- 거래 이력 고유 번호, 자동 증가
  `buyer_id` bigint DEFAULT NULL, -- 구매자, users 참조 (탈퇴 시 NULL로 변경)
  `seller_id` bigint DEFAULT NULL, -- 판매자, users 참조 (탈퇴 시 NULL로 변경)
  `card_id` bigint NOT NULL, -- 거래된 카드, cards 참조
  `final_price` int NOT NULL, -- 실제 거래 체결 금액 (원 단위)
  `trade_date` timestamp NULL DEFAULT CURRENT_TIMESTAMP, -- 거래 체결 일시, 자동 기록
  PRIMARY KEY (`history_id`), -- history_id를 기본키로 사용
  KEY `buyer_id` (`buyer_id`), -- 구매자별 거래 내역 조회 속도 향상
  KEY `seller_id` (`seller_id`), -- 판매자별 거래 내역 조회 속도 향상
  KEY `card_id` (`card_id`), -- 카드별 거래 이력 조회 속도 향상
  KEY `idx_card_trade_date` (`card_id`, `trade_date`), -- 카드별 최근 거래가 조회 속도 향상
  CONSTRAINT `trade_history_ibfk_1` FOREIGN KEY (`buyer_id`)
    REFERENCES `users` (`user_id`) ON DELETE SET NULL, -- 구매자 탈퇴 시 NULL로 변경, 이력 보존
  CONSTRAINT `trade_history_ibfk_2` FOREIGN KEY (`seller_id`)
    REFERENCES `users` (`user_id`) ON DELETE SET NULL, -- 판매자 탈퇴 시 NULL로 변경, 이력 보존
  CONSTRAINT `trade_history_ibfk_3` FOREIGN KEY (`card_id`)
    REFERENCES `cards` (`card_id`) -- 거래 이력 있는 카드는 삭제 불가
) ENGINE=InnoDB
  AUTO_INCREMENT=1
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;
  
-- 이벤트 스케줄러 활성화: 예약된 자동 작업 기능을 켬
SET GLOBAL event_scheduler = ON;
-- 정기 데이터 정리: 거래 내역이 너무 쌓이면 검색이 느려지므로 5년 지난 내역은 자동 삭제
CREATE EVENT IF NOT EXISTS archive_old_trades
ON SCHEDULE EVERY 1 WEEK -- 매주 1번씩 실행
COMMENT '매주, 5년 이상 된 거래 내역 정리로 DB 최적화'
DO DELETE FROM trade_history WHERE trade_date < DATE_SUB(NOW(), INTERVAL 5 YEAR);
