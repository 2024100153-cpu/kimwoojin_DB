/*
 포켓몬 카드 도감 및 컬렉션 관리 시스템 DB 스키마
 제작일: 2026-04-07
 주요 기능: 카드 상세 정보, 기술/특성 저장, 외부 API 연동(ID), 유저 도감 관리
*/

-- 데이터베이스 생성 및 선택 (필요 시 주석 해제 후 사용)
-- CREATE DATABASE IF NOT EXISTS pokemon_card_db;
-- USE pokemon_card_db;

-- 1. 카드 세트 테이블 (예: SV4a 샤이니트레저, S12a VSTAR 유니버스 등)
CREATE TABLE card_sets (
    set_id INT AUTO_INCREMENT PRIMARY KEY,
    set_code VARCHAR(20) NOT NULL UNIQUE,     -- 예: SV4a, S12a
    series_name VARCHAR(50),                  -- 예: 스칼렛&바이올렛, 소드&실드
    set_name_ko VARCHAR(100) NOT NULL,        -- 한국어 세트명
    set_name_en VARCHAR(100),                 -- 영어 세트명 (API 연동용)
    total_cards INT,                          -- 세트 내 총 카드 수
    release_date DATE,                        -- 출시일
    logo_url TEXT                             -- 세트 심볼 이미지 (S3 경로)
);

-- 2. 카드 상세 정보 테이블 (기술 및 외부 ID 포함)
CREATE TABLE cards (
    card_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    set_id INT NOT NULL,
    
    -- 외부 API 식별자 및 카드 번호
    external_id VARCHAR(50) UNIQUE,           -- 글로벌 고유 ID (예: sv3pt5-1) 시세 연동용
    card_number VARCHAR(20) NOT NULL,         -- 카드 실물 번호 (예: 001/190)
    
    -- 기본 정보
    card_name_ko VARCHAR(100) NOT NULL,       -- 카드 이름 (한글)
    card_name_en VARCHAR(100),                -- 카드 이름 (영문)
    rarity_code VARCHAR(10) NULL,             -- 레어도 (NULL 허용: SAR, SR, AR 등)
    rarity_score INT DEFAULT 0,               -- 랭킹 산정용 점수
    attribute VARCHAR(20),                    -- 속성 (풀, 불꽃, 물, 초, 투구 등)
    card_type VARCHAR(20),                    -- 유형 (기본, 1진화, 2진화, 서포트, 아이템)
    hp INT,                                   -- 포켓몬 체력
    
    -- 기술 및 특성 정보 (추가됨)
    ability_name VARCHAR(100),                -- 특성 이름
    ability_description TEXT,                 -- 특성 설명
    skill_1_name VARCHAR(100),                -- 기술 1 이름
    skill_1_description TEXT,                 -- 기술 1 효과 및 데미지
    skill_2_name VARCHAR(100),                -- 기술 2 이름
    skill_2_description TEXT,                 -- 기술 2 효과 및 데미지
    
    official_image_url TEXT,                  -- 공식 DB 이미지 URL
    
    -- 외래키 및 인덱스 설정
    FOREIGN KEY (set_id) REFERENCES card_sets(set_id),
    UNIQUE KEY uq_set_card (set_id, card_number), -- 한 세트 내 번호 중복 방지
    INDEX idx_card_name (card_name_ko),           -- 카드 이름 검색 최적화
    INDEX idx_external_id (external_id)           -- API 연동 시 검색 속도 향상
);

-- 3. 유저 정보 테이블
CREATE TABLE users (
    user_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    nickname VARCHAR(50) NOT NULL UNIQUE,
    profile_img_url TEXT,                     -- 유저 프로필 사진 (S3)
    total_collection_score INT DEFAULT 0,     -- 보유 카드의 rarity_score 합계
    ranking_points INT DEFAULT 0,             -- 활동 점수
    tier VARCHAR(20) DEFAULT 'BRONZE',        -- 유저 등급
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- 4. 유저 보유 카드 (나의 도감/컬렉션)
CREATE TABLE user_collections (
    collection_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    card_id BIGINT NOT NULL,
    quantity INT DEFAULT 1,                   -- 보유 수량
    condition_grade VARCHAR(5) DEFAULT 'A',   -- 상태 (S: 미개봉, A: 미품, B: 플레이용)
    acquired_method VARCHAR(20),              -- 등록 방식 (SCAN: 스캔, MANUAL: 직접, TRADE: 거래)
    scanned_img_url TEXT,                     -- 유저가 직접 촬영한 사진
    is_public BOOLEAN DEFAULT TRUE,           -- 내 도감 공개 여부
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- 관계 설정
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (card_id) REFERENCES cards(card_id)
);

-- 5. 시세 정보 테이블 (선택 사항)
CREATE TABLE card_prices (
    price_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    card_id BIGINT NOT NULL,
    market_price DECIMAL(10, 2),              -- 현재 시세
    currency VARCHAR(10) DEFAULT 'USD',       -- 통화 (USD, KRW 등)
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (card_id) REFERENCES cards(card_id) ON DELETE CASCADE
);