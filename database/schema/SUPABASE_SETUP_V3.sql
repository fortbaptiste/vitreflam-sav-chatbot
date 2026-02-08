-- =====================================================
-- VITREFLAM - SCHEMA V3 OPTIMISE
-- Memoire hierarchique + Hybrid Search + Assurances
-- =====================================================

-- =====================================================
-- EXTENSIONS REQUISES
-- =====================================================

CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pg_trgm;  -- Pour recherche fuzzy

-- =====================================================
-- PARTIE 1: CLIENTS (enrichi)
-- =====================================================

CREATE TABLE IF NOT EXISTS clients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Identifiants
    email VARCHAR(255) UNIQUE NOT NULL,
    telephone VARCHAR(20),
    prestashop_id VARCHAR(50),

    -- Identite
    nom VARCHAR(255),
    prenom VARCHAR(255),

    -- Metriques globales
    nb_commandes INT DEFAULT 0,
    nb_incidents INT DEFAULT 0,
    total_achats DECIMAL(10,2) DEFAULT 0,
    remises_totales DECIMAL(10,2) DEFAULT 0,

    -- Segmentation
    segment VARCHAR(50) DEFAULT 'nouveau'
        CHECK (segment IN ('nouveau', 'regulier', 'vip', 'difficile', 'inactif')),

    -- Score de risque (0-100, plus c'est haut plus le client est "a risque")
    risk_score INT DEFAULT 0 CHECK (risk_score BETWEEN 0 AND 100),

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    derniere_interaction TIMESTAMPTZ DEFAULT NOW(),

    -- Notes pour le bot (texte libre)
    notes_importantes TEXT
);

CREATE INDEX idx_clients_email ON clients(email);
CREATE INDEX idx_clients_prestashop ON clients(prestashop_id);
CREATE INDEX idx_clients_segment ON clients(segment);

-- =====================================================
-- PARTIE 2: ASSURANCES CLIENT (NOUVEAU)
-- Track les assurances souscrites par commande
-- =====================================================

CREATE TABLE IF NOT EXISTS client_assurances (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID REFERENCES clients(id) ON DELETE CASCADE,

    -- Commande concernee
    commande_id VARCHAR(50) NOT NULL,

    -- Type d'assurance
    type_assurance VARCHAR(50) NOT NULL
        CHECK (type_assurance IN ('transport', 'montage', 'both')),

    -- Dates importantes
    date_souscription DATE NOT NULL,
    date_livraison DATE,

    -- Delais de declaration (calcules automatiquement)
    delai_transport_expire_at TIMESTAMPTZ,  -- date_livraison + 2 jours
    delai_montage_expire_at TIMESTAMPTZ,    -- date_livraison + 8 jours

    -- Utilisation
    assurance_utilisee BOOLEAN DEFAULT FALSE,
    date_utilisation TIMESTAMPTZ,
    incident_id UUID,  -- Reference vers l'incident si utilise

    -- Metadata
    montant_assurance DECIMAL(10,2),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_assurances_client ON client_assurances(client_id);
CREATE INDEX idx_assurances_commande ON client_assurances(commande_id);
CREATE INDEX idx_assurances_type ON client_assurances(type_assurance);

-- Trigger pour calculer les dates d'expiration
CREATE OR REPLACE FUNCTION calculate_assurance_expiry()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.date_livraison IS NOT NULL THEN
        NEW.delai_transport_expire_at := NEW.date_livraison + INTERVAL '2 days';
        NEW.delai_montage_expire_at := NEW.date_livraison + INTERVAL '8 days';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_calculate_assurance_expiry
BEFORE INSERT OR UPDATE ON client_assurances
FOR EACH ROW
EXECUTE FUNCTION calculate_assurance_expiry();

-- =====================================================
-- PARTIE 3: PREFERENCES CLIENT (NOUVEAU)
-- Memoire long terme des preferences
-- =====================================================

CREATE TABLE IF NOT EXISTS client_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID REFERENCES clients(id) ON DELETE CASCADE,

    -- Categorie et cle de preference
    category VARCHAR(50) NOT NULL
        CHECK (category IN ('produit', 'communication', 'livraison', 'paiement', 'autre')),
    preference_key VARCHAR(100) NOT NULL,
    preference_value TEXT NOT NULL,

    -- Confiance (0-1, plus c'est haut plus on est sur)
    confidence FLOAT DEFAULT 0.5 CHECK (confidence BETWEEN 0 AND 1),

    -- Source de la preference
    source_type VARCHAR(50) DEFAULT 'inferred'
        CHECK (source_type IN ('explicit', 'inferred', 'historical')),
    source_conversation_id UUID,

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Contrainte unicite
    UNIQUE(client_id, category, preference_key)
);

CREATE INDEX idx_preferences_client ON client_preferences(client_id);
CREATE INDEX idx_preferences_category ON client_preferences(category);

-- =====================================================
-- PARTIE 4: CONVERSATIONS (enrichi)
-- =====================================================

CREATE TABLE IF NOT EXISTS conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID REFERENCES clients(id) ON DELETE CASCADE,

    -- Contexte
    canal VARCHAR(50) DEFAULT 'chatbot'
        CHECK (canal IN ('chatbot', 'widget', 'api', 'email')),

    -- Intent et sujet
    intent_principal VARCHAR(100),
    sujet VARCHAR(255),  -- Nouveau: sujet detecte
    commande_concernee VARCHAR(50),

    -- Statut
    statut VARCHAR(50) DEFAULT 'en_cours'
        CHECK (statut IN ('en_cours', 'resolu', 'escalade', 'abandonne')),
    satisfaction_score INT CHECK (satisfaction_score BETWEEN 1 AND 5),

    -- NOUVEAU: Resume et memoire
    resume TEXT,                    -- Resume genere par LLM
    resume_updated_at TIMESTAMPTZ,  -- Quand le resume a ete mis a jour
    key_facts JSONB DEFAULT '[]',   -- Faits cles extraits

    -- Metriques conversation
    nb_messages INT DEFAULT 0,
    nb_tokens_total INT DEFAULT 0,  -- Pour tracking couts

    -- Timestamps
    started_at TIMESTAMPTZ DEFAULT NOW(),
    ended_at TIMESTAMPTZ,

    -- Metadata flexible
    metadata JSONB DEFAULT '{}'::jsonb
);

CREATE INDEX idx_conversations_client ON conversations(client_id);
CREATE INDEX idx_conversations_statut ON conversations(statut);
CREATE INDEX idx_conversations_started ON conversations(started_at DESC);

-- =====================================================
-- PARTIE 5: MESSAGES (enrichi)
-- =====================================================

CREATE TABLE IF NOT EXISTS messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE,

    -- Contenu
    role VARCHAR(20) NOT NULL CHECK (role IN ('user', 'assistant', 'system', 'summary')),
    contenu TEXT NOT NULL,

    -- NOUVEAU: Embedding du message pour RAG sur historique
    embedding vector(1536),

    -- Intent et entites
    intent_detecte VARCHAR(100),
    entites_extraites JSONB DEFAULT '{}'::jsonb,

    -- NOUVEAU: Importance du message (pour summarization)
    importance_score FLOAT DEFAULT 0.5 CHECK (importance_score BETWEEN 0 AND 1),

    -- NOUVEAU: Tokens utilises
    tokens_count INT DEFAULT 0,

    -- Timestamp
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_messages_conversation ON messages(conversation_id);
CREATE INDEX idx_messages_created ON messages(created_at DESC);
CREATE INDEX idx_messages_role ON messages(role);

-- Index vectoriel sur messages (pour recherche dans historique)
CREATE INDEX ON messages
USING hnsw (embedding vector_cosine_ops)
WITH (m = 16, ef_construction = 64);

-- =====================================================
-- PARTIE 6: MEMOIRE HIERARCHIQUE (NOUVEAU)
-- Court terme / Moyen terme / Long terme
-- =====================================================

CREATE TABLE IF NOT EXISTS client_memory (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID REFERENCES clients(id) ON DELETE CASCADE,

    -- Type de memoire
    memory_type VARCHAR(20) NOT NULL
        CHECK (memory_type IN ('short', 'medium', 'long')),

    -- Contenu
    content TEXT NOT NULL,

    -- Embedding pour recherche semantique
    embedding vector(1536),

    -- Importance (pour tri et nettoyage)
    importance_score FLOAT DEFAULT 0.5 CHECK (importance_score BETWEEN 0 AND 1),

    -- Source
    source_type VARCHAR(50),  -- 'conversation', 'incident', 'preference', 'manual'
    source_id UUID,           -- ID de la source

    -- Expiration
    expires_at TIMESTAMPTZ,   -- NULL = jamais (long terme)

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    last_accessed_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_memory_client ON client_memory(client_id);
CREATE INDEX idx_memory_type ON client_memory(memory_type);
CREATE INDEX idx_memory_expires ON client_memory(expires_at);

-- Index vectoriel sur memoire
CREATE INDEX ON client_memory
USING hnsw (embedding vector_cosine_ops)
WITH (m = 16, ef_construction = 64);

-- =====================================================
-- PARTIE 7: INCIDENTS (enrichi avec assurance)
-- =====================================================

CREATE TABLE IF NOT EXISTS incidents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID REFERENCES clients(id) ON DELETE CASCADE,
    conversation_id UUID REFERENCES conversations(id),

    -- Commande
    commande_id VARCHAR(50),

    -- Type et details
    type_incident VARCHAR(100) NOT NULL,
    sous_type VARCHAR(100),  -- Nouveau: plus de precision
    description TEXT,

    -- NOUVEAU: Lien avec assurance
    assurance_id UUID REFERENCES client_assurances(id),
    assurance_applicable BOOLEAN DEFAULT FALSE,
    dans_delai_assurance BOOLEAN,  -- Calcule automatiquement

    -- Produits concernes
    produits_concernes JSONB DEFAULT '[]'::jsonb,

    -- Photos/preuves
    photos_recues BOOLEAN DEFAULT FALSE,
    photos_urls JSONB DEFAULT '[]'::jsonb,

    -- Resolution
    statut VARCHAR(50) DEFAULT 'ouvert'
        CHECK (statut IN ('ouvert', 'en_cours', 'en_attente_photos', 'resolu', 'escalade', 'rembourse', 'refuse')),
    solution_appliquee TEXT,
    remise_accordee DECIMAL(5,2) DEFAULT 0,
    avoir_emis BOOLEAN DEFAULT FALSE,
    montant_avoir DECIMAL(10,2),

    -- Responsabilite
    responsabilite VARCHAR(50)
        CHECK (responsabilite IN ('transporteur', 'client', 'vitreflam', 'fournisseur', 'indetermine')),

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    resolved_at TIMESTAMPTZ,

    -- Metadata
    metadata JSONB DEFAULT '{}'::jsonb
);

CREATE INDEX idx_incidents_client ON incidents(client_id);
CREATE INDEX idx_incidents_statut ON incidents(statut);
CREATE INDEX idx_incidents_type ON incidents(type_incident);
CREATE INDEX idx_incidents_commande ON incidents(commande_id);

-- =====================================================
-- PARTIE 8: PRODUITS CLIENT
-- =====================================================

CREATE TABLE IF NOT EXISTS produits_client (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID REFERENCES clients(id) ON DELETE CASCADE,

    -- Commande
    commande_id VARCHAR(50) NOT NULL,

    -- Produit
    reference_produit VARCHAR(100),
    nom_produit VARCHAR(255),
    quantite INT DEFAULT 1,
    prix_unitaire DECIMAL(10,2),
    prix_total DECIMAL(10,2),

    -- Specifications Vitreflam
    type_verre VARCHAR(50) DEFAULT 'ceramique'
        CHECK (type_verre IN ('ceramique', 'vitroceramique')),
    dimensions JSONB DEFAULT '{}'::jsonb,  -- {largeur_mm, hauteur_mm, epaisseur_mm}
    forme VARCHAR(50),  -- 'rectangle', 'carre', 'trapeze', 'arrondi', etc.
    options JSONB DEFAULT '[]'::jsonb,  -- ['autonettoyant', 'joint_noir']

    -- Livraison
    date_commande DATE,
    date_expedition DATE,
    date_livraison DATE,
    numero_suivi VARCHAR(100),
    statut_livraison VARCHAR(50),

    -- Assurances souscrites pour ce produit
    assurance_transport BOOLEAN DEFAULT FALSE,
    assurance_montage BOOLEAN DEFAULT FALSE,

    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_produits_client ON produits_client(client_id);
CREATE INDEX idx_produits_commande ON produits_client(commande_id);

-- =====================================================
-- PARTIE 9: KNOWLEDGE BASE (optimise)
-- =====================================================

CREATE TABLE IF NOT EXISTS knowledge_base (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Contenu
    contenu TEXT NOT NULL,

    -- Categorisation
    categorie VARCHAR(100) NOT NULL,
    sous_categorie VARCHAR(100),
    tags TEXT[] DEFAULT '{}',

    -- Source
    source_document VARCHAR(255),
    section VARCHAR(255),

    -- Embeddings
    embedding vector(1536),

    -- NOUVEAU: Full-text search vector
    fts_vector tsvector GENERATED ALWAYS AS (
        setweight(to_tsvector('french', coalesce(categorie, '')), 'A') ||
        setweight(to_tsvector('french', coalesce(sous_categorie, '')), 'B') ||
        setweight(to_tsvector('french', coalesce(contenu, '')), 'C')
    ) STORED,

    -- Metadata
    metadata JSONB DEFAULT '{}'::jsonb,
    priorite INT DEFAULT 5,  -- 1-10, plus c'est haut plus c'est important

    -- Gestion
    actif BOOLEAN DEFAULT TRUE,
    version INT DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index vectoriel HNSW optimise
CREATE INDEX idx_kb_embedding ON knowledge_base
USING hnsw (embedding vector_cosine_ops)
WITH (m = 24, ef_construction = 100);

-- Index full-text pour hybrid search
CREATE INDEX idx_kb_fts ON knowledge_base USING gin(fts_vector);

-- Index categorisation
CREATE INDEX idx_kb_categorie ON knowledge_base(categorie);
CREATE INDEX idx_kb_actif ON knowledge_base(actif);
CREATE INDEX idx_kb_priorite ON knowledge_base(priorite DESC);

-- =====================================================
-- PARTIE 10: FONCTIONS AMELIOREES
-- =====================================================

-- Fonction HYBRID SEARCH (semantic + keyword)
CREATE OR REPLACE FUNCTION hybrid_search_knowledge(
    query_text TEXT,
    query_embedding vector(1536),
    match_count INT DEFAULT 5,
    semantic_weight FLOAT DEFAULT 0.7,
    keyword_weight FLOAT DEFAULT 0.3
)
RETURNS TABLE (
    id UUID,
    contenu TEXT,
    categorie VARCHAR,
    sous_categorie VARCHAR,
    combined_score FLOAT,
    match_type VARCHAR
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH semantic_results AS (
        SELECT
            kb.id,
            kb.contenu,
            kb.categorie,
            kb.sous_categorie,
            (1 - (kb.embedding <=> query_embedding)) * semantic_weight AS score,
            'semantic'::VARCHAR AS match_type,
            ROW_NUMBER() OVER (ORDER BY kb.embedding <=> query_embedding) AS rank
        FROM knowledge_base kb
        WHERE kb.actif = TRUE AND kb.embedding IS NOT NULL
        LIMIT 20
    ),
    keyword_results AS (
        SELECT
            kb.id,
            kb.contenu,
            kb.categorie,
            kb.sous_categorie,
            ts_rank_cd(kb.fts_vector, plainto_tsquery('french', query_text)) * keyword_weight AS score,
            'keyword'::VARCHAR AS match_type,
            ROW_NUMBER() OVER (ORDER BY ts_rank_cd(kb.fts_vector, plainto_tsquery('french', query_text)) DESC) AS rank
        FROM knowledge_base kb
        WHERE kb.actif = TRUE
          AND kb.fts_vector @@ plainto_tsquery('french', query_text)
        LIMIT 20
    ),
    combined AS (
        SELECT
            COALESCE(s.id, k.id) AS id,
            COALESCE(s.contenu, k.contenu) AS contenu,
            COALESCE(s.categorie, k.categorie) AS categorie,
            COALESCE(s.sous_categorie, k.sous_categorie) AS sous_categorie,
            -- RRF Score
            (COALESCE(1.0/(60 + s.rank), 0) + COALESCE(1.0/(60 + k.rank), 0)) AS combined_score,
            CASE
                WHEN s.id IS NOT NULL AND k.id IS NOT NULL THEN 'both'
                WHEN s.id IS NOT NULL THEN 'semantic'
                ELSE 'keyword'
            END AS match_type
        FROM semantic_results s
        FULL OUTER JOIN keyword_results k ON s.id = k.id
    )
    SELECT c.id, c.contenu, c.categorie, c.sous_categorie, c.combined_score, c.match_type
    FROM combined c
    ORDER BY c.combined_score DESC
    LIMIT match_count;
END;
$$;

-- Fonction: Verifier assurance client
CREATE OR REPLACE FUNCTION check_client_assurance(
    p_client_email VARCHAR,
    p_commande_id VARCHAR,
    p_type_assurance VARCHAR  -- 'transport' ou 'montage'
)
RETURNS TABLE (
    has_assurance BOOLEAN,
    is_within_deadline BOOLEAN,
    assurance_id UUID,
    deadline TIMESTAMPTZ,
    already_used BOOLEAN
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_client_id UUID;
BEGIN
    -- Trouver le client
    SELECT id INTO v_client_id FROM clients WHERE email = p_client_email;

    IF v_client_id IS NULL THEN
        RETURN QUERY SELECT FALSE, FALSE, NULL::UUID, NULL::TIMESTAMPTZ, FALSE;
        RETURN;
    END IF;

    RETURN QUERY
    SELECT
        TRUE AS has_assurance,
        CASE
            WHEN p_type_assurance = 'transport' THEN NOW() <= ca.delai_transport_expire_at
            WHEN p_type_assurance = 'montage' THEN NOW() <= ca.delai_montage_expire_at
            ELSE FALSE
        END AS is_within_deadline,
        ca.id AS assurance_id,
        CASE
            WHEN p_type_assurance = 'transport' THEN ca.delai_transport_expire_at
            ELSE ca.delai_montage_expire_at
        END AS deadline,
        ca.assurance_utilisee AS already_used
    FROM client_assurances ca
    WHERE ca.client_id = v_client_id
      AND ca.commande_id = p_commande_id
      AND (ca.type_assurance = p_type_assurance OR ca.type_assurance = 'both')
    ORDER BY ca.date_souscription DESC
    LIMIT 1;

    -- Si pas d'assurance trouvee
    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, FALSE, NULL::UUID, NULL::TIMESTAMPTZ, FALSE;
    END IF;
END;
$$;

-- Fonction: Obtenir contexte client complet V3
CREATE OR REPLACE FUNCTION get_client_context_v3(p_email VARCHAR)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_client_id UUID;
    v_result JSONB;
BEGIN
    SELECT id INTO v_client_id FROM clients WHERE email = p_email;

    IF v_client_id IS NULL THEN
        RETURN jsonb_build_object('found', false);
    END IF;

    SELECT jsonb_build_object(
        'found', true,
        'client', (
            SELECT jsonb_build_object(
                'id', c.id,
                'nom', c.nom,
                'prenom', c.prenom,
                'email', c.email,
                'segment', c.segment,
                'risk_score', c.risk_score,
                'nb_commandes', c.nb_commandes,
                'nb_incidents', c.nb_incidents,
                'notes', c.notes_importantes
            )
            FROM clients c WHERE c.id = v_client_id
        ),
        'assurances_actives', (
            SELECT COALESCE(jsonb_agg(jsonb_build_object(
                'commande_id', ca.commande_id,
                'type', ca.type_assurance,
                'transport_expire', ca.delai_transport_expire_at,
                'montage_expire', ca.delai_montage_expire_at,
                'utilisee', ca.assurance_utilisee
            )), '[]'::jsonb)
            FROM client_assurances ca
            WHERE ca.client_id = v_client_id
              AND ca.assurance_utilisee = FALSE
              AND (ca.delai_montage_expire_at > NOW() OR ca.delai_transport_expire_at > NOW())
        ),
        'incidents_ouverts', (
            SELECT COALESCE(jsonb_agg(jsonb_build_object(
                'id', i.id,
                'type', i.type_incident,
                'commande', i.commande_id,
                'statut', i.statut,
                'assurance_applicable', i.assurance_applicable,
                'date', i.created_at
            )), '[]'::jsonb)
            FROM incidents i
            WHERE i.client_id = v_client_id
              AND i.statut IN ('ouvert', 'en_cours', 'en_attente_photos')
        ),
        'commandes_recentes', (
            SELECT COALESCE(jsonb_agg(jsonb_build_object(
                'commande_id', p.commande_id,
                'produit', p.nom_produit,
                'dimensions', p.dimensions,
                'date_commande', p.date_commande,
                'date_livraison', p.date_livraison,
                'assurance_transport', p.assurance_transport,
                'assurance_montage', p.assurance_montage
            )), '[]'::jsonb)
            FROM produits_client p
            WHERE p.client_id = v_client_id
            ORDER BY p.date_commande DESC
            LIMIT 5
        ),
        'preferences', (
            SELECT COALESCE(jsonb_agg(jsonb_build_object(
                'category', cp.category,
                'key', cp.preference_key,
                'value', cp.preference_value,
                'confidence', cp.confidence
            )), '[]'::jsonb)
            FROM client_preferences cp
            WHERE cp.client_id = v_client_id
              AND cp.confidence > 0.6
        ),
        'memoire_long_terme', (
            SELECT COALESCE(jsonb_agg(cm.content), '[]'::jsonb)
            FROM client_memory cm
            WHERE cm.client_id = v_client_id
              AND cm.memory_type = 'long'
              AND cm.importance_score > 0.7
            ORDER BY cm.importance_score DESC
            LIMIT 5
        )
    ) INTO v_result;

    RETURN v_result;
END;
$$;

-- Fonction: Ajouter memoire client
CREATE OR REPLACE FUNCTION add_client_memory(
    p_client_id UUID,
    p_memory_type VARCHAR,
    p_content TEXT,
    p_embedding vector(1536) DEFAULT NULL,
    p_importance FLOAT DEFAULT 0.5,
    p_source_type VARCHAR DEFAULT 'inferred',
    p_source_id UUID DEFAULT NULL,
    p_expires_days INT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
    v_memory_id UUID;
    v_expires_at TIMESTAMPTZ;
BEGIN
    -- Calculer expiration
    IF p_expires_days IS NOT NULL THEN
        v_expires_at := NOW() + (p_expires_days || ' days')::INTERVAL;
    ELSIF p_memory_type = 'short' THEN
        v_expires_at := NOW() + INTERVAL '1 day';
    ELSIF p_memory_type = 'medium' THEN
        v_expires_at := NOW() + INTERVAL '30 days';
    ELSE
        v_expires_at := NULL;  -- Long terme = jamais
    END IF;

    INSERT INTO client_memory (
        client_id, memory_type, content, embedding,
        importance_score, source_type, source_id, expires_at
    )
    VALUES (
        p_client_id, p_memory_type, p_content, p_embedding,
        p_importance, p_source_type, p_source_id, v_expires_at
    )
    RETURNING id INTO v_memory_id;

    RETURN v_memory_id;
END;
$$;

-- Fonction: Rechercher dans memoire client
CREATE OR REPLACE FUNCTION search_client_memory(
    p_client_id UUID,
    p_query_embedding vector(1536),
    p_memory_types VARCHAR[] DEFAULT ARRAY['short', 'medium', 'long'],
    p_limit INT DEFAULT 10
)
RETURNS TABLE (
    id UUID,
    memory_type VARCHAR,
    content TEXT,
    importance_score FLOAT,
    similarity FLOAT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        cm.id,
        cm.memory_type,
        cm.content,
        cm.importance_score,
        1 - (cm.embedding <=> p_query_embedding) AS similarity
    FROM client_memory cm
    WHERE cm.client_id = p_client_id
      AND cm.memory_type = ANY(p_memory_types)
      AND (cm.expires_at IS NULL OR cm.expires_at > NOW())
      AND cm.embedding IS NOT NULL
    ORDER BY cm.embedding <=> p_query_embedding
    LIMIT p_limit;
END;
$$;

-- Fonction: Nettoyer memoire expiree (a executer periodiquement)
CREATE OR REPLACE FUNCTION cleanup_expired_memory()
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    v_deleted INT;
BEGIN
    DELETE FROM client_memory
    WHERE expires_at IS NOT NULL AND expires_at < NOW();

    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    RETURN v_deleted;
END;
$$;

-- =====================================================
-- PARTIE 11: TRIGGERS AMELIORES
-- =====================================================

-- Trigger: Mettre a jour segment et risk_score
CREATE OR REPLACE FUNCTION update_client_metrics()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE clients SET
        nb_incidents = (
            SELECT COUNT(*) FROM incidents WHERE client_id = NEW.client_id
        ),
        segment = CASE
            WHEN (SELECT COUNT(*) FROM incidents WHERE client_id = NEW.client_id AND statut = 'escalade') >= 2 THEN 'difficile'
            WHEN (SELECT COUNT(*) FROM incidents WHERE client_id = NEW.client_id) >= 5 THEN 'difficile'
            WHEN nb_commandes >= 10 AND (SELECT COUNT(*) FROM incidents WHERE client_id = NEW.client_id) <= 1 THEN 'vip'
            WHEN nb_commandes >= 3 THEN 'regulier'
            WHEN derniere_interaction < NOW() - INTERVAL '6 months' THEN 'inactif'
            ELSE 'nouveau'
        END,
        risk_score = LEAST(100, (
            (SELECT COUNT(*) FROM incidents WHERE client_id = NEW.client_id) * 15 +
            (SELECT COUNT(*) FROM incidents WHERE client_id = NEW.client_id AND statut = 'escalade') * 25 +
            (SELECT COUNT(*) FROM incidents WHERE client_id = NEW.client_id AND responsabilite = 'client') * 10
        ))
    WHERE id = NEW.client_id;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trigger_update_client_metrics
AFTER INSERT OR UPDATE ON incidents
FOR EACH ROW
EXECUTE FUNCTION update_client_metrics();

-- Trigger: Compter messages dans conversation
CREATE OR REPLACE FUNCTION update_conversation_message_count()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE conversations SET
        nb_messages = nb_messages + 1,
        nb_tokens_total = nb_tokens_total + COALESCE(NEW.tokens_count, 0)
    WHERE id = NEW.conversation_id;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trigger_update_conversation_count
AFTER INSERT ON messages
FOR EACH ROW
EXECUTE FUNCTION update_conversation_message_count();

-- =====================================================
-- PARTIE 12: ROW LEVEL SECURITY
-- =====================================================

ALTER TABLE clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE client_assurances ENABLE ROW LEVEL SECURITY;
ALTER TABLE client_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE client_memory ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE incidents ENABLE ROW LEVEL SECURITY;
ALTER TABLE produits_client ENABLE ROW LEVEL SECURITY;
ALTER TABLE knowledge_base ENABLE ROW LEVEL SECURITY;

-- Policies service_role (full access)
CREATE POLICY "service_role_all" ON clients FOR ALL TO service_role USING (true);
CREATE POLICY "service_role_all" ON client_assurances FOR ALL TO service_role USING (true);
CREATE POLICY "service_role_all" ON client_preferences FOR ALL TO service_role USING (true);
CREATE POLICY "service_role_all" ON client_memory FOR ALL TO service_role USING (true);
CREATE POLICY "service_role_all" ON conversations FOR ALL TO service_role USING (true);
CREATE POLICY "service_role_all" ON messages FOR ALL TO service_role USING (true);
CREATE POLICY "service_role_all" ON incidents FOR ALL TO service_role USING (true);
CREATE POLICY "service_role_all" ON produits_client FOR ALL TO service_role USING (true);
CREATE POLICY "service_role_all" ON knowledge_base FOR ALL TO service_role USING (true);

-- Policy anon (read only sur knowledge_base)
CREATE POLICY "anon_read_kb" ON knowledge_base FOR SELECT TO anon USING (actif = true);

-- =====================================================
-- PARTIE 13: VUES UTILES
-- =====================================================

-- Vue: Dashboard client complet
CREATE OR REPLACE VIEW v_client_dashboard AS
SELECT
    c.id,
    c.email,
    c.nom || ' ' || COALESCE(c.prenom, '') AS nom_complet,
    c.segment,
    c.risk_score,
    c.nb_commandes,
    c.nb_incidents,
    c.total_achats,
    c.derniere_interaction,
    (SELECT COUNT(*) FROM incidents i WHERE i.client_id = c.id AND i.statut = 'ouvert') AS incidents_ouverts,
    (SELECT COUNT(*) FROM client_assurances ca WHERE ca.client_id = c.id AND ca.assurance_utilisee = FALSE) AS assurances_actives,
    (SELECT COUNT(*) FROM conversations co WHERE co.client_id = c.id) AS total_conversations
FROM clients c;

-- Vue: Incidents avec contexte assurance
CREATE OR REPLACE VIEW v_incidents_avec_assurance AS
SELECT
    i.*,
    c.email AS client_email,
    c.nom || ' ' || COALESCE(c.prenom, '') AS client_nom,
    c.segment AS client_segment,
    c.risk_score AS client_risk,
    ca.type_assurance,
    ca.delai_transport_expire_at,
    ca.delai_montage_expire_at,
    CASE
        WHEN ca.id IS NOT NULL AND i.type_incident LIKE '%transport%'
             AND NOW() <= ca.delai_transport_expire_at THEN TRUE
        WHEN ca.id IS NOT NULL AND i.type_incident LIKE '%montage%'
             AND NOW() <= ca.delai_montage_expire_at THEN TRUE
        ELSE FALSE
    END AS couvert_par_assurance
FROM incidents i
JOIN clients c ON c.id = i.client_id
LEFT JOIN client_assurances ca ON ca.id = i.assurance_id;

-- =====================================================
-- FIN DU SCHEMA V3
-- =====================================================
