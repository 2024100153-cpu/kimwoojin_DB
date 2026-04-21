/* ============================================================
[0. 코드/공통 테이블]
- 문자열 남발 방지 + 데이터 정합성 확보
============================================================ */

/* 카드 희귀도 코드 */
CREATE TABLE rarity_codes (
    rarity_code VARCHAR(20) PRIMARY KEY, -- ex) R, SR, UR
    description VARCHAR(100)
) ENGINE=InnoDB;

/* 유저 티어 */
CREATE TABLE user_tiers (
    tier_code VARCHAR(20) PRIMARY KEY -- ex) BRONZE, SILVER
) ENGINE=InnoDB;

/* 카드 속성 (불, 물, 전기 등) */
CREATE TABLE card_attributes (
    attribute_id INT AUTO_INCREMENT PRIMARY KEY,
    attribute_name VARCHAR(20) UNIQUE -- 속성 이름 고유
) ENGINE=InnoDB;

/* ============================================================
[1. 카드 세트]
- 파생 데이터 제거, 조회 중심 인덱스 유지
============================================================ */
CREATE TABLE card_sets (
    set_id INT AUTO_INCREMENT PRIMARY KEY,
    set_code VARCHAR(20) NOT NULL UNIQUE,
    series_name VARCHAR(50), -- 필요 시 별도 테이블 분리 가능
    set_name_ko VARCHAR(100) NOT NULL,
    release_date DATE,
    logo_url VARCHAR(2048),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_release_series (release_date, series_name)
) ENGINE=InnoDB;

/* ============================================================
[2. 카드 기본 정보]
- 속성은 별도 테이블로 분리 (확장성 확보)
============================================================ */
CREATE TABLE cards (
    card_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    set_id INT NOT NULL,
    external_id VARCHAR(100) UNIQUE,
    card_number VARCHAR(20) NOT NULL,
    card_name_ko VARCHAR(100) NOT NULL,
    rarity_code VARCHAR(20),
    official_image_url VARCHAR(2048),

    FOREIGN KEY (set_id) REFERENCES card_sets(set_id) ON DELETE RESTRICT,
    FOREIGN KEY (rarity_code) REFERENCES rarity_codes(rarity_code),

    UNIQUE KEY uq_set_card (set_id, card_number),
    INDEX idx_card_name (card_name_ko)
) ENGINE=InnoDB;

/* 카드 - 속성 매핑 (다대다) */
CREATE TABLE card_attribute_map (
    card_id BIGINT,
    attribute_id INT,
    PRIMARY KEY (card_id, attribute_id),
    FOREIGN KEY (card_id) REFERENCES cards(card_id) ON DELETE CASCADE,
    FOREIGN KEY (attribute_id) REFERENCES card_attributes(attribute_id)
) ENGINE=InnoDB;

/* ============================================================
[3. 유저]
- 상태/티어 분리로 무결성 확보
============================================================ */
CREATE TABLE users (
    user_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    nickname VARCHAR(50) NOT NULL UNIQUE,
    profile_img_url VARCHAR(2048),
    tier_code VARCHAR(20),
    status ENUM('ACTIVE','SUSPENDED','WITHDRAWN') DEFAULT 'ACTIVE',
    last_login_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (tier_code) REFERENCES user_tiers(tier_code)
) ENGINE=InnoDB;

/* ============================================================
[4. 인증 토큰]
- 해시 기반 저장 (보안 + 인덱스 효율)
============================================================ */
CREATE TABLE user_auth_tokens (
    token_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    refresh_token_hash CHAR(64) NOT NULL UNIQUE, -- SHA-256 기준
    device_info VARCHAR(255),
    ip_address VARCHAR(45),
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB;

/* ============================================================
[5. 유저 카드 (개별 단위 관리)]
- 수량 대신 row 단위 관리 → 거래 추적 가능
============================================================ */
CREATE TABLE user_cards (
    user_card_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    card_id BIGINT NOT NULL,
    condition_grade ENUM('S','A','B','C') DEFAULT 'A',
    acquired_method VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (card_id) REFERENCES cards(card_id)
) ENGINE=InnoDB;

/* ============================================================
[6. 위치 테이블]
- 문자열 location 제거 → 좌표 기반 검색 가능
============================================================ */
CREATE TABLE locations (
    location_id INT AUTO_INCREMENT PRIMARY KEY,
    city VARCHAR(50),
    district VARCHAR(50),
    latitude DECIMAL(10,7),
    longitude DECIMAL(10,7),
    INDEX idx_geo (latitude, longitude)
) ENGINE=InnoDB;

/* ============================================================
[7. 마켓플레이스]
- 실제 검색 쿼리 기준 인덱스 구성
============================================================ */
CREATE TABLE marketplace_listings (
    listing_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    seller_id BIGINT NOT NULL,
    user_card_id BIGINT, -- 개별 카드 기준
    price DECIMAL(15,0) NOT NULL,
    contact_info VARCHAR(100) NOT NULL,
    location_id INT,
    description TEXT,
    status ENUM('ON_SALE','RESERVED','SOLD','CANCELLED') DEFAULT 'ON_SALE',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    sold_at TIMESTAMP NULL,

    FOREIGN KEY (seller_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (user_card_id) REFERENCES user_cards(user_card_id) ON DELETE SET NULL,
    FOREIGN KEY (location_id) REFERENCES locations(location_id),

    INDEX idx_market_search (status, price),
    INDEX idx_market_location (location_id, status)
) ENGINE=InnoDB;

/* ============================================================
[8. 거래 내역]
- listing 기반 추적 가능하도록 설계
============================================================ */
CREATE TABLE trade_history (
    history_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    listing_id BIGINT,
    buyer_id BIGINT,
    seller_id BIGINT,
    card_id BIGINT NOT NULL,
    final_price DECIMAL(15,0) NOT NULL,
    trade_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    transaction_uuid VARCHAR(100) UNIQUE,

    FOREIGN KEY (listing_id) REFERENCES marketplace_listings(listing_id),
    FOREIGN KEY (buyer_id) REFERENCES users(user_id) ON DELETE SET NULL,
    FOREIGN KEY (seller_id) REFERENCES users(user_id) ON DELETE SET NULL,
    FOREIGN KEY (card_id) REFERENCES cards(card_id),

    INDEX idx_trade_date (trade_date)
) ENGINE=InnoDB;

/* ============================================================
[9. 거래 아카이브]
- 삭제 대신 이동 (감사/법적 대응)
============================================================ */
CREATE TABLE trade_history_archive LIKE trade_history;

/* ============================================================
[10. 이벤트 스케줄러]
- 5년 지난 데이터는 archive로 이동 후 삭제
============================================================ */
SET GLOBAL event_scheduler = ON;

CREATE EVENT archive_old_trades
ON SCHEDULE EVERY 1 MONTH
DO
BEGIN
    INSERT INTO trade_history_archive
    SELECT * FROM trade_history
    WHERE trade_date < DATE_SUB(NOW(), INTERVAL 5 YEAR);

    DELETE FROM trade_history
    WHERE trade_date < DATE_SUB(NOW(), INTERVAL 5 YEAR);
END;
