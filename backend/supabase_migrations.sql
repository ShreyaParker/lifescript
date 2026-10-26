ALTER TABLE users ADD COLUMN IF NOT EXISTS onboarding_complete BOOLEAN DEFAULT false;
ALTER TABLE users ADD COLUMN IF NOT EXISTS archetype_data JSONB DEFAULT '{}'::jsonb;
ALTER TABLE users ADD COLUMN IF NOT EXISTS macro_goals TEXT[] DEFAULT '{}';

CREATE TABLE IF NOT EXISTS user_media (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    media_type VARCHAR(50), -- 'book' or 'movie'
    title VARCHAR(255) NOT NULL,
    current_status VARCHAR(50), -- 'reading', 'watching', 'completed'
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 1. Upgrade User Meta & Psychographic Archetype Profiles
ALTER TABLE users ADD COLUMN IF NOT EXISTS primary_north_star VARCHAR(255);
ALTER TABLE users ADD COLUMN IF NOT EXISTS side_anchors JSONB DEFAULT '[]'::jsonb;
ALTER TABLE users ADD COLUMN IF NOT EXISTS visual_theme VARCHAR(50) DEFAULT 'Minimalist';
ALTER TABLE users ADD COLUMN IF NOT EXISTS ai_persona VARCHAR(50) DEFAULT 'Therapeutic';

-- 2. Create Fluid Focus Matrix Table
CREATE TABLE IF NOT EXISTS focus_matrix (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    is_primary BOOLEAN DEFAULT false,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Create Multi-Modal Media & Cultural Logs Table
CREATE TABLE IF NOT EXISTS gallery_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    log_type VARCHAR(50), -- 'book', 'movie', 'hobby'
    title VARCHAR(255) NOT NULL,
    associated_mood VARCHAR(50),
    auto_detected BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Upgrade Journal Entries for Multi-Modal Resonance Processing
ALTER TABLE journal_entries ADD COLUMN IF NOT EXISTS image_url TEXT;
ALTER TABLE journal_entries ADD COLUMN IF NOT EXISTS image_analysis_context TEXT;
ALTER TABLE journal_entries ADD COLUMN IF NOT EXISTS visual_sentiment_score FLOAT;
ALTER TABLE journal_entries ADD COLUMN IF NOT EXISTS mood_color_hex VARCHAR(7) DEFAULT '#E8D7F9';
