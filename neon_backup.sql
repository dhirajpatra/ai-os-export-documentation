--
-- PostgreSQL database dump
--

\restrict Vhe4BW7wvGKm3ncpn6rMXQeMtmIYtgViBtaKmz8NEsKbdBx0RCNNCmPOQGyE4zJ

-- Dumped from database version 16.14 (146758d)
-- Dumped by pg_dump version 17.10 (Debian 17.10-0+deb13u1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

DROP DATABASE IF EXISTS neondb;
--
-- Name: neondb; Type: DATABASE; Schema: -; Owner: neondb_owner
--

CREATE DATABASE neondb WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE_PROVIDER = libc LOCALE = 'C.UTF-8';


ALTER DATABASE neondb OWNER TO neondb_owner;

\unrestrict Vhe4BW7wvGKm3ncpn6rMXQeMtmIYtgViBtaKmz8NEsKbdBx0RCNNCmPOQGyE4zJ
\connect neondb
\restrict Vhe4BW7wvGKm3ncpn6rMXQeMtmIYtgViBtaKmz8NEsKbdBx0RCNNCmPOQGyE4zJ

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: vector; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA public;


--
-- Name: EXTENSION vector; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION vector IS 'vector data type and ivfflat and hnsw access methods';


--
-- Name: set_updated_at(); Type: FUNCTION; Schema: public; Owner: neondb_owner
--

CREATE FUNCTION public.set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$;


ALTER FUNCTION public.set_updated_at() OWNER TO neondb_owner;

--
-- Name: update_po_templates_updated_at(); Type: FUNCTION; Schema: public; Owner: neondb_owner
--

CREATE FUNCTION public.update_po_templates_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_po_templates_updated_at() OWNER TO neondb_owner;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: agent_memory; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.agent_memory (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    org_id uuid NOT NULL,
    agent_name text NOT NULL,
    memory_type text NOT NULL,
    scope_type text NOT NULL,
    scope_id uuid,
    key text NOT NULL,
    value jsonb NOT NULL,
    confidence numeric(5,2) DEFAULT 50 NOT NULL,
    source text,
    observation_count integer DEFAULT 1 NOT NULL,
    last_observed_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone,
    embedding public.vector(384),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT agent_memory_memory_type_check CHECK ((memory_type = ANY (ARRAY['customer_preference'::text, 'shipment_pattern'::text, 'hs_code_learned'::text, 'vendor_behavior'::text, 'invoice_style'::text, 'country_rule'::text, 'workflow_shortcut'::text, 'risk_pattern'::text, 'seasonal_pattern'::text]))),
    CONSTRAINT agent_memory_scope_type_check CHECK ((scope_type = ANY (ARRAY['org'::text, 'contact'::text, 'product'::text, 'route'::text])))
);


ALTER TABLE public.agent_memory OWNER TO neondb_owner;

--
-- Name: approval_requests; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.approval_requests (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    org_id uuid NOT NULL,
    workflow_id uuid NOT NULL,
    workflow_step_id uuid,
    order_id uuid,
    document_id uuid,
    requested_by text NOT NULL,
    title text NOT NULL,
    description text,
    ai_confidence numeric(5,2) NOT NULL,
    risk_flags jsonb DEFAULT '[]'::jsonb NOT NULL,
    suggested_action text,
    diff_before jsonb,
    diff_after jsonb,
    status text DEFAULT 'pending'::text NOT NULL,
    assigned_to uuid,
    reviewed_by uuid,
    reviewed_at timestamp with time zone,
    review_note text,
    expires_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT approval_requests_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text, 'expired'::text])))
);


ALTER TABLE public.approval_requests OWNER TO neondb_owner;

--
-- Name: audit_log; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.audit_log (
    id bigint NOT NULL,
    org_id uuid NOT NULL,
    actor_type text NOT NULL,
    actor_id text NOT NULL,
    action text NOT NULL,
    entity_type text NOT NULL,
    entity_id text NOT NULL,
    old_value jsonb,
    new_value jsonb,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    ip_address inet,
    user_agent text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.audit_log OWNER TO neondb_owner;

--
-- Name: audit_log_id_seq; Type: SEQUENCE; Schema: public; Owner: neondb_owner
--

CREATE SEQUENCE public.audit_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.audit_log_id_seq OWNER TO neondb_owner;

--
-- Name: audit_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: neondb_owner
--

ALTER SEQUENCE public.audit_log_id_seq OWNED BY public.audit_log.id;


--
-- Name: contacts; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.contacts (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    org_id uuid NOT NULL,
    type text NOT NULL,
    name text NOT NULL,
    country character(2),
    currency character(3),
    payment_terms text,
    whatsapp text,
    email text,
    address jsonb,
    bank_details jsonb,
    custom_fields jsonb DEFAULT '{}'::jsonb NOT NULL,
    ai_notes text,
    preferred_doc_format text,
    avg_order_value numeric(14,2),
    risk_score smallint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT contacts_risk_score_check CHECK (((risk_score >= 0) AND (risk_score <= 100))),
    CONSTRAINT contacts_type_check CHECK ((type = ANY (ARRAY['buyer'::text, 'supplier'::text, 'freight'::text, 'customs_broker'::text, 'bank'::text])))
);


ALTER TABLE public.contacts OWNER TO neondb_owner;

--
-- Name: country_trade_rules; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.country_trade_rules (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    from_country character(2) NOT NULL,
    to_country character(2) NOT NULL,
    hs_code_prefix text,
    rule_type text NOT NULL,
    rule_value jsonb NOT NULL,
    source text,
    effective_from date,
    effective_to date,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT country_trade_rules_rule_type_check CHECK ((rule_type = ANY (ARRAY['import_duty'::text, 'export_restriction'::text, 'banned'::text, 'permit_required'::text, 'quota'::text, 'vat'::text, 'gst'::text, 'preference'::text])))
);


ALTER TABLE public.country_trade_rules OWNER TO neondb_owner;

--
-- Name: documents; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.documents (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    org_id uuid NOT NULL,
    order_id uuid,
    doc_type text NOT NULL,
    reference_number text,
    status text DEFAULT 'draft'::text NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    parent_version_id uuid,
    storage_path text,
    file_size_bytes integer,
    mime_type text,
    checksum text,
    generated_by text,
    ai_confidence numeric(5,2),
    generation_prompt_id uuid,
    extracted_data jsonb,
    reviewed_by uuid,
    reviewed_at timestamp with time zone,
    review_notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT documents_doc_type_check CHECK ((doc_type = ANY (ARRAY['purchase_order'::text, 'commercial_invoice'::text, 'packing_list'::text, 'certificate_of_origin'::text, 'shipping_bill'::text, 'bill_of_lading'::text, 'airway_bill'::text, 'lc_document'::text, 'insurance_certificate'::text, 'fumigation_certificate'::text, 'phytosanitary'::text, 'gsp_certificate'::text, 'customs_declaration'::text, 'delivery_note'::text, 'other'::text]))),
    CONSTRAINT documents_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'pending_review'::text, 'approved'::text, 'rejected'::text, 'sent'::text, 'archived'::text])))
);


ALTER TABLE public.documents OWNER TO neondb_owner;

--
-- Name: hitl_corrections; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.hitl_corrections (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    workflow_id uuid NOT NULL,
    order_id uuid,
    buyer_key text,
    field_name text NOT NULL,
    wrong_value text,
    correct_value text NOT NULL,
    correction_source text DEFAULT 'hitl_approval'::text NOT NULL,
    corrected_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.hitl_corrections OWNER TO neondb_owner;

--
-- Name: TABLE hitl_corrections; Type: COMMENT; Schema: public; Owner: neondb_owner
--

COMMENT ON TABLE public.hitl_corrections IS 'Field-level human corrections from HITL review — used to improve per-org templates';


--
-- Name: COLUMN hitl_corrections.buyer_key; Type: COMMENT; Schema: public; Owner: neondb_owner
--

COMMENT ON COLUMN public.hitl_corrections.buyer_key IS 'Matches po_templates.buyer_key — links corrections back to the template they should improve';


--
-- Name: COLUMN hitl_corrections.wrong_value; Type: COMMENT; Schema: public; Owner: neondb_owner
--

COMMENT ON COLUMN public.hitl_corrections.wrong_value IS 'Value the system extracted before human correction; NULL if field was entirely missing';


--
-- Name: hs_codes; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.hs_codes (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    code text NOT NULL,
    description text NOT NULL,
    chapter text,
    parent_code text,
    notes text,
    embedding public.vector(384),
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.hs_codes OWNER TO neondb_owner;

--
-- Name: logistics_rate_cards; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.logistics_rate_cards (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    vendor_id uuid NOT NULL,
    charge_type text NOT NULL,
    unit_type text NOT NULL,
    rate numeric(14,2) NOT NULL,
    minimum_charge numeric(14,2),
    hazardous_rules jsonb,
    gst_applicable boolean DEFAULT false NOT NULL,
    effective_date date,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.logistics_rate_cards OWNER TO neondb_owner;

--
-- Name: logistics_vendors; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.logistics_vendors (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    org_id uuid NOT NULL,
    name text NOT NULL,
    country character(2),
    supported_ports text[],
    contact_info jsonb,
    services text[],
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.logistics_vendors OWNER TO neondb_owner;

--
-- Name: mcp_api_keys; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.mcp_api_keys (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    key_hash text NOT NULL,
    key_prefix text NOT NULL,
    environment text DEFAULT 'live'::text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    last_used_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT mcp_api_keys_environment_check CHECK ((environment = ANY (ARRAY['live'::text, 'test'::text])))
);


ALTER TABLE public.mcp_api_keys OWNER TO neondb_owner;

--
-- Name: mcp_billing; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.mcp_billing (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    period_start date NOT NULL,
    period_end date NOT NULL,
    plan text NOT NULL,
    calls_used integer DEFAULT 0 NOT NULL,
    calls_limit integer NOT NULL,
    cost_usd numeric(10,4) DEFAULT 0,
    is_paid boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.mcp_billing OWNER TO neondb_owner;

--
-- Name: mcp_usage_log; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.mcp_usage_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    service text NOT NULL,
    action text NOT NULL,
    request_ms integer,
    tokens_used integer DEFAULT 0,
    cost_usd numeric(10,6) DEFAULT 0,
    status text DEFAULT 'ok'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT mcp_usage_log_status_check CHECK ((status = ANY (ARRAY['ok'::text, 'error'::text, 'quota_exceeded'::text])))
);


ALTER TABLE public.mcp_usage_log OWNER TO neondb_owner;

--
-- Name: messages; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.messages (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    org_id uuid NOT NULL,
    order_id uuid,
    contact_id uuid,
    channel text NOT NULL,
    direction text NOT NULL,
    from_address text,
    to_address text,
    subject text,
    body text,
    body_lang character(2),
    body_translated text,
    attachments jsonb DEFAULT '[]'::jsonb NOT NULL,
    intent text,
    extracted_data jsonb,
    ai_processed boolean DEFAULT false NOT NULL,
    status text DEFAULT 'received'::text NOT NULL,
    external_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT messages_channel_check CHECK ((channel = ANY (ARRAY['whatsapp'::text, 'email'::text, 'sms'::text, 'portal'::text]))),
    CONSTRAINT messages_direction_check CHECK ((direction = ANY (ARRAY['inbound'::text, 'outbound'::text]))),
    CONSTRAINT messages_status_check CHECK ((status = ANY (ARRAY['received'::text, 'processing'::text, 'processed'::text, 'sent'::text, 'delivered'::text, 'failed'::text])))
);


ALTER TABLE public.messages OWNER TO neondb_owner;

--
-- Name: order_items; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.order_items (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    order_id uuid NOT NULL,
    product_id uuid,
    description text NOT NULL,
    hs_code text,
    quantity numeric(14,4) NOT NULL,
    unit text NOT NULL,
    unit_price numeric(14,4) NOT NULL,
    discount_pct numeric(5,2) DEFAULT 0,
    total_price numeric(14,2) GENERATED ALWAYS AS (round(((quantity * unit_price) * ((1)::numeric - (COALESCE(discount_pct, (0)::numeric) / (100)::numeric))), 2)) STORED
);


ALTER TABLE public.order_items OWNER TO neondb_owner;

--
-- Name: orders; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.orders (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    org_id uuid NOT NULL,
    order_number text NOT NULL,
    buyer_id uuid NOT NULL,
    status text DEFAULT 'draft'::text NOT NULL,
    currency character(3) DEFAULT 'USD'::bpchar NOT NULL,
    total_amount numeric(14,2),
    payment_terms text,
    incoterms text,
    port_of_loading text,
    port_of_discharge text,
    destination_country character(2),
    po_source text,
    po_raw_text text,
    po_file_id uuid,
    workflow_id uuid,
    assigned_to uuid,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT orders_po_source_check CHECK ((po_source = ANY (ARRAY['whatsapp'::text, 'email'::text, 'portal'::text, 'manual'::text]))),
    CONSTRAINT orders_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'po_received'::text, 'documents_pending'::text, 'compliance_check'::text, 'awaiting_approval'::text, 'approved'::text, 'dispatched'::text, 'in_transit'::text, 'delivered'::text, 'cancelled'::text])))
);


ALTER TABLE public.orders OWNER TO neondb_owner;

--
-- Name: organizations; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.organizations (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    name text NOT NULL,
    slug text NOT NULL,
    country character(2) DEFAULT 'IN'::bpchar NOT NULL,
    iec_code text,
    gstin text,
    vat_number text,
    plan text DEFAULT 'starter'::text NOT NULL,
    timezone text DEFAULT 'Asia/Kolkata'::text NOT NULL,
    default_currency character(3) DEFAULT 'INR'::bpchar NOT NULL,
    whatsapp_number text,
    smtp_config jsonb,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    extraction_rules jsonb DEFAULT '{}'::jsonb NOT NULL,
    rules_bundle_version text DEFAULT '0.0.0'::text NOT NULL,
    rules_bundle_synced_at timestamp with time zone,
    CONSTRAINT organizations_plan_check CHECK ((plan = ANY (ARRAY['starter'::text, 'growth'::text, 'enterprise'::text])))
);


ALTER TABLE public.organizations OWNER TO neondb_owner;

--
-- Name: COLUMN organizations.extraction_rules; Type: COMMENT; Schema: public; Owner: neondb_owner
--

COMMENT ON COLUMN public.organizations.extraction_rules IS 'Per-org extraction overrides: commodity_hs map, unit_aliases, default_incoterms, default_currency. Merged with global COMMODITY_HS in RuleBasedExtractor at runtime.';


--
-- Name: po_templates; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.po_templates (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    buyer_key text NOT NULL,
    buyer_name text,
    buyer_country character(2),
    currency character varying(5),
    payment_terms text,
    incoterms character varying(10),
    destination_port text,
    field_anchors jsonb DEFAULT '[]'::jsonb NOT NULL,
    use_count integer DEFAULT 1 NOT NULL,
    avg_confidence double precision DEFAULT 80.0 NOT NULL,
    last_extraction_confidence double precision,
    llm_fallback_count integer DEFAULT 0 NOT NULL,
    template_hit_count integer DEFAULT 0 NOT NULL,
    last_used_at timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.po_templates OWNER TO neondb_owner;

--
-- Name: TABLE po_templates; Type: COMMENT; Schema: public; Owner: neondb_owner
--

COMMENT ON TABLE public.po_templates IS 'Buyer-specific PO extraction templates — learned and improved per shipment';


--
-- Name: COLUMN po_templates.buyer_key; Type: COMMENT; Schema: public; Owner: neondb_owner
--

COMMENT ON COLUMN public.po_templates.buyer_key IS 'Normalised slug of buyer_name — used as lookup key';


--
-- Name: COLUMN po_templates.field_anchors; Type: COMMENT; Schema: public; Owner: neondb_owner
--

COMMENT ON COLUMN public.po_templates.field_anchors IS 'JSONB array: [{field, signals, value}] — label patterns that reliably appear in this buyer PO format';


--
-- Name: COLUMN po_templates.use_count; Type: COMMENT; Schema: public; Owner: neondb_owner
--

COMMENT ON COLUMN public.po_templates.use_count IS 'Total times this template was consulted (matched or not)';


--
-- Name: COLUMN po_templates.avg_confidence; Type: COMMENT; Schema: public; Owner: neondb_owner
--

COMMENT ON COLUMN public.po_templates.avg_confidence IS 'Running average confidence across all extractions for this buyer';


--
-- Name: COLUMN po_templates.llm_fallback_count; Type: COMMENT; Schema: public; Owner: neondb_owner
--

COMMENT ON COLUMN public.po_templates.llm_fallback_count IS 'Times LLM was still needed despite template existing';


--
-- Name: COLUMN po_templates.template_hit_count; Type: COMMENT; Schema: public; Owner: neondb_owner
--

COMMENT ON COLUMN public.po_templates.template_hit_count IS 'Times template was sufficient — LLM skipped';


--
-- Name: products; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.products (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    org_id uuid NOT NULL,
    sku text NOT NULL,
    description text NOT NULL,
    hs_code text,
    hs_validated_at timestamp with time zone,
    hs_confidence numeric(5,2),
    unit text DEFAULT 'KG'::text NOT NULL,
    default_currency character(3) DEFAULT 'USD'::bpchar NOT NULL,
    unit_price numeric(14,4),
    country_of_origin character(2),
    custom_fields jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.products OWNER TO neondb_owner;

--
-- Name: prompt_registry; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.prompt_registry (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    org_id uuid,
    agent_name text NOT NULL,
    prompt_key text NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    system_prompt text NOT NULL,
    user_template text NOT NULL,
    output_schema jsonb,
    fallback_model text,
    fallback_prompt_id uuid,
    avg_confidence numeric(5,2),
    success_count integer DEFAULT 0 NOT NULL,
    failure_count integer DEFAULT 0 NOT NULL,
    avg_latency_ms integer,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.prompt_registry OWNER TO neondb_owner;

--
-- Name: shipment_events; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.shipment_events (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    shipment_id uuid NOT NULL,
    event_code text NOT NULL,
    description text NOT NULL,
    location text,
    occurred_at timestamp with time zone NOT NULL,
    source text,
    raw_data jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.shipment_events OWNER TO neondb_owner;

--
-- Name: shipments; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.shipments (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    org_id uuid NOT NULL,
    order_id uuid NOT NULL,
    carrier text,
    service_type text,
    tracking_number text,
    bl_number text,
    awb_number text,
    container_number text,
    vessel_name text,
    voyage_number text,
    port_of_loading text,
    port_of_discharge text,
    etd date,
    eta date,
    actual_departure timestamp with time zone,
    actual_arrival timestamp with time zone,
    status text DEFAULT 'booking_pending'::text NOT NULL,
    last_event text,
    last_event_at timestamp with time zone,
    carrier_raw_response jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT shipments_status_check CHECK ((status = ANY (ARRAY['booking_pending'::text, 'booked'::text, 'cargo_received'::text, 'customs_cleared'::text, 'laden_on_vessel'::text, 'in_transit'::text, 'arrived'::text, 'customs_hold'::text, 'delivered'::text])))
);


ALTER TABLE public.shipments OWNER TO neondb_owner;

--
-- Name: user_sessions; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.user_sessions (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    user_id uuid NOT NULL,
    org_id uuid NOT NULL,
    token text NOT NULL,
    ip_address inet,
    user_agent text,
    is_active boolean DEFAULT true NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.user_sessions OWNER TO neondb_owner;

--
-- Name: users; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.users (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    org_id uuid NOT NULL,
    email text NOT NULL,
    name text NOT NULL,
    role text DEFAULT 'operator'::text NOT NULL,
    password_hash text,
    is_active boolean DEFAULT true NOT NULL,
    last_login_at timestamp with time zone,
    preferences jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    auth_provider text DEFAULT 'email'::text NOT NULL,
    google_sub text,
    CONSTRAINT users_auth_provider_check CHECK ((auth_provider = ANY (ARRAY['email'::text, 'google'::text]))),
    CONSTRAINT users_role_check CHECK ((role = ANY (ARRAY['owner'::text, 'admin'::text, 'manager'::text, 'operator'::text, 'viewer'::text])))
);


ALTER TABLE public.users OWNER TO neondb_owner;

--
-- Name: workflow_steps; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.workflow_steps (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    workflow_id uuid NOT NULL,
    step_name text NOT NULL,
    agent_name text,
    status text DEFAULT 'pending'::text NOT NULL,
    input jsonb,
    output jsonb,
    error jsonb,
    ai_confidence numeric(5,2),
    tokens_used integer,
    latency_ms integer,
    retry_count smallint DEFAULT 0 NOT NULL,
    started_at timestamp with time zone,
    completed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT workflow_steps_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'running'::text, 'completed'::text, 'failed'::text, 'skipped'::text, 'compensated'::text])))
);


ALTER TABLE public.workflow_steps OWNER TO neondb_owner;

--
-- Name: workflows; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.workflows (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    org_id uuid NOT NULL,
    order_id uuid,
    name text NOT NULL,
    status text DEFAULT 'running'::text NOT NULL,
    current_step text,
    temporal_workflow_id text,
    temporal_run_id text,
    state_snapshot jsonb DEFAULT '{}'::jsonb NOT NULL,
    context jsonb DEFAULT '{}'::jsonb NOT NULL,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    completed_at timestamp with time zone,
    timeout_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT workflows_status_check CHECK ((status = ANY (ARRAY['running'::text, 'paused'::text, 'awaiting_human'::text, 'completed'::text, 'failed'::text, 'compensating'::text])))
);


ALTER TABLE public.workflows OWNER TO neondb_owner;

--
-- Name: audit_log id; Type: DEFAULT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.audit_log ALTER COLUMN id SET DEFAULT nextval('public.audit_log_id_seq'::regclass);


--
-- Data for Name: agent_memory; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.agent_memory (id, org_id, agent_name, memory_type, scope_type, scope_id, key, value, confidence, source, observation_count, last_observed_at, expires_at, embedding, created_at, updated_at) FROM stdin;
c7660db6-26ed-4cf6-8971-62a72444e166	00000000-0000-0000-0000-000000000001	faq_agent	country_rule	org	\N	faq_products	{"answer": "We export seafood products, frozen shrimp, spices, coir products, cashew products, agricultural commodities, FMCG products, and engineering goods.", "question": "What products do you export?"}	95.00	seed	1	2026-05-22 12:21:03.608489+00	\N	[-0.0047523575,-0.028465314,-0.045529522,0.03449615,0.1262335,0.0350641,0.020265095,0.017992241,-0.046696577,-0.03223495,0.038738016,-0.036105923,-0.05844277,-0.021310939,0.018905016,-0.00044834914,-0.025241727,0.019436387,-0.050930437,-0.03782402,-0.011074452,0.020324951,-0.0076115075,0.016500177,0.024398146,-0.00010002237,0.008018722,-0.041130323,-0.00095471536,-0.13428201,-0.09989346,-0.00811085,0.017417729,0.018792083,0.061572637,0.0719627,0.06737605,-0.042073768,0.024798773,-0.048841476,0.01748625,-0.04035217,-0.025121344,-0.019469848,0.045117926,-0.010688064,0.06575792,0.051504534,0.039861318,0.06583697,-0.010216634,0.036230963,-0.15441447,0.013266144,0.008260224,-0.048729498,-0.043865345,0.002628661,0.03458952,0.03379231,-0.016293457,-0.06249598,-0.061886832,0.04678879,-0.0032903426,-0.02559291,-0.11086749,0.08646272,-0.09349118,-0.06496623,-0.11983056,-0.04358691,-0.110407434,0.038489375,-0.036159784,-0.07833049,0.059281327,-0.08493352,-0.041450746,-0.009993742,-0.026205359,0.053540707,-0.113484696,0.009655936,-0.00463923,0.034275103,0.018077692,0.058497623,-0.04321412,0.06135322,-0.047216155,-0.068152554,0.06693203,0.043705653,-0.13327625,0.062950894,0.08624354,0.00551241,0.060071122,0.02982139,0.055604886,0.012600751,0.0606371,-0.06506088,-0.12288982,-0.0440553,-0.011977015,-0.0016285781,0.06274703,0.07560524,-0.08026474,0.07421351,-0.12335608,-0.06542841,-0.03589748,-0.03884317,-0.027461784,-0.044264827,0.021860048,0.006931654,0.037822194,0.006562505,0.11678886,0.018618234,-0.1041824,0.041013386,0.034397718,-5.8858585e-33,-0.032352757,-0.034464154,-0.044009656,0.054430064,-0.019337304,0.051381238,0.0011528583,-0.024164006,0.044248074,0.052798003,-0.054567955,0.106815964,-0.092563644,0.17570956,0.09302388,0.0058703804,0.032584928,0.013640779,0.05349761,0.017375413,0.0138714705,0.006016157,-0.004036969,0.10304423,0.04427542,-0.02236609,-0.013852295,-0.041092902,-0.018028578,0.009555872,0.040983662,0.011907299,0.055044185,-0.069893815,-0.054575797,0.028771242,-0.07390017,-0.07093151,0.010062323,0.06455431,-0.050483342,0.04106743,-0.04013685,0.024244469,0.044461362,0.012474371,0.016696386,0.005280186,0.048683196,0.015097621,-0.07425927,-0.0036873019,0.039030213,-0.08247179,-0.01292345,-0.052010942,0.035118602,-0.060204957,0.025861528,0.0018181722,-0.06332683,0.10534239,-0.012630525,0.013567601,0.014415194,0.04506334,0.00017968798,0.0053789797,-0.03337321,-0.0382506,-0.05444692,0.0060704704,0.08643452,-0.05163201,0.075194076,0.06876373,-0.0204323,0.047062833,-0.0069347816,-0.058895506,-0.08613951,0.012932562,-0.056020148,0.0019604124,-0.019163473,0.034202438,-0.049543295,-0.020099778,0.03667669,0.04070039,-0.05099595,0.01883228,-0.00811562,0.0013645238,-0.09213482,2.9468626e-33,0.0028669448,-0.060912468,0.019916242,-0.010543595,0.0316493,-0.0084476145,0.018859886,0.038304925,-0.028953614,0.04846892,-0.05999262,-0.07135038,0.034974292,0.019186107,-0.05248314,0.007524244,0.070415966,0.047525477,0.032838814,-0.08980243,-0.026254283,0.09555946,0.04499297,0.062221617,0.013431826,0.03767773,-0.0315369,0.0037132946,-0.005441711,-0.015722144,0.07710864,0.002597397,0.025521418,-0.00060298137,-0.07981175,0.0070227333,-0.011267806,0.025194498,0.0883402,0.048328325,0.06886034,-0.02910873,0.01583871,0.12575234,-0.03874629,-0.058825735,-0.08567557,-0.03363915,0.05630415,-0.022221858,0.076508634,0.058971148,-0.043610808,-0.08591379,0.013569457,0.050582208,0.023661675,-0.019790554,-0.022501756,-0.06930891,0.0065338537,0.055522103,0.045488816,-0.0034025728,-0.007631028,0.0067103505,0.070922695,0.04226035,-0.06313161,0.049151447,0.0329491,0.00827368,-0.01326635,-0.04049378,-0.06476264,-0.01741464,0.00700329,-0.01505854,0.046144437,0.0066607287,-0.020401105,-0.010842462,0.04660263,0.037371144,0.046432734,-0.07934052,-0.028089518,-0.05674576,0.082165614,0.04116693,-0.05484769,0.003553167,-0.018346308,0.02820017,0.02059493,-1.491279e-08,-0.02099319,0.0067577013,0.04100431,0.05952796,-0.06916878,-0.0022977192,0.0136535335,0.050032184,0.027934883,-0.02856343,0.013432737,0.0043665236,-0.07188203,0.024818689,0.07331851,0.00047031377,0.07857532,0.05587996,-0.0016604464,-0.09533768,0.0009770634,0.057463348,0.10401236,0.019954504,0.006097519,-0.06681606,0.060595304,0.03323209,0.09679349,-0.007959977,-0.04284588,0.040604644,-0.036982927,-0.010272795,-0.038609087,-0.067970864,0.009853377,-0.035764113,-0.075750664,0.026346661,-0.015478944,-0.030740375,-0.032801945,-2.6099067e-05,-0.03924296,-0.06462686,-0.113981016,-0.060931027,0.0043450273,0.006412475,0.013283176,-0.021638047,0.056707196,0.009933921,0.037415575,0.018299408,-0.04298888,-0.038317103,0.028031286,-0.029222488,0.054344453,-0.02944515,0.08857819,0.008046005]	2026-05-22 12:21:03.608489+00	2026-05-22 12:21:03.608489+00
66f06b67-06c5-4b92-96f1-1f254011a254	00000000-0000-0000-0000-000000000001	faq_agent	country_rule	org	\N	faq_payment_terms	{"answer": "We support advance payment, Letter of Credit (LC), Documents Against Payment (DP), and open account for trusted buyers. For new buyers, LC or partial advance payment is preferred.", "question": "What payment terms do you offer?"}	95.00	seed	1	2026-05-22 12:21:03.638771+00	\N	[-0.0032649033,0.03721324,0.013509492,-0.005450998,-0.04172288,-0.00762715,0.024050653,-0.009781379,0.028634198,0.01395402,0.009318512,-0.09050319,-0.02475861,-0.018443715,0.021061977,-0.024787493,-0.014488075,0.030078577,0.051646866,0.023366231,-0.049736656,-0.0066509806,-0.017041441,0.01161236,0.13524428,-0.047878716,0.06907471,0.05976112,0.0077819848,-0.03190474,0.018006822,0.00055631076,0.09203215,0.0008323173,-0.058311593,-0.031047197,-0.064131625,-0.055713084,-0.08784584,-0.00530386,0.035125934,-0.024230422,-0.018381594,-0.045347307,0.016432088,-0.014820822,0.041760247,0.054076582,-0.046309825,0.042870075,0.025500787,-0.032380152,-0.099311635,0.100531876,-0.022557115,-0.07413495,-0.0067068394,0.009929215,0.010038835,-0.07048282,0.037287712,-0.059626862,-0.08878646,0.08079738,0.016626533,0.03814457,-0.025163751,0.01933629,-0.0628458,0.015811842,-0.032270215,-0.03739352,0.010768439,-0.011023152,-0.009826184,0.006477724,0.091836214,-0.06309313,-0.04754266,-0.016202867,-0.038285583,0.026465228,-0.017879905,-0.09155554,-0.010974493,-0.029457785,-0.029481506,0.07145946,0.027322365,-0.01341155,0.030587638,-0.015586704,0.044579793,-0.12207382,-0.035889436,-0.055645384,0.03863209,-0.11232238,0.013796115,0.008261982,0.08039068,0.012791841,-0.010626342,-0.029708475,-0.0045024958,0.054248385,-0.033727504,0.017672716,0.027846642,0.024681203,-0.13317348,-0.014736845,0.032134943,-0.06966934,-0.039048824,0.026082328,-0.07409749,0.019012168,0.19079132,0.000730629,0.038311437,0.06773787,-0.05357044,-0.10603342,-0.09712689,-0.027318552,-0.06723605,-5.7199364e-33,0.027788619,0.0013833499,-0.033127476,0.02153233,0.036979876,0.031269755,0.03867218,0.09085296,-0.02501506,0.12560457,0.036687735,0.06800693,0.01940765,0.04557427,-0.018201163,0.012088338,-0.058216713,0.0998775,0.08000331,0.10171756,-0.0098559465,0.0102430545,0.033126973,0.074828506,0.04523275,-0.10322088,-0.028308092,-0.015331215,0.06114256,-0.025952183,0.029907072,0.020782776,0.08529956,-0.040616713,-0.010026559,0.03220852,-0.025049115,-0.032691706,0.07049428,-0.05086828,-0.065157525,0.01314802,-0.07909831,-0.041321013,0.018087931,0.019727422,0.06374694,-0.010905013,-0.026414206,0.102731586,-0.053468533,-0.011119192,-0.104661405,-0.010434189,-0.04207046,0.015856063,0.016396824,0.016486267,-0.09980945,-0.048716724,-0.031631526,-0.071068004,-0.004696075,-0.049627617,-0.016742958,0.0008402966,-0.049933836,0.0008716374,0.040513776,0.025377959,-0.09428671,0.017579682,0.13753122,-0.007136321,0.029577015,-0.029237568,-0.00033244133,-0.030225553,0.0050234883,0.017948855,-0.0798722,0.043541364,2.2246126e-05,0.102242135,0.033649888,0.10315569,0.059560772,-0.010700447,0.040267862,-0.106270894,-0.07748822,-0.02373453,0.016678972,-0.021889633,0.05279859,2.5492658e-33,-0.018439196,-0.017235627,-0.066407986,0.06636944,0.046558402,0.04182518,-0.01622278,0.081543535,0.084484726,0.03363624,-0.05024022,0.03357716,0.0052815243,0.03267216,0.030084623,-0.06720756,-0.03404496,-0.03132348,0.08078623,0.03347686,0.018699292,0.03516734,0.043731555,-0.008071551,0.08929657,-0.004911465,-0.018665036,0.011339372,-0.077396326,0.06791859,-0.0059665963,0.008223609,-0.004062445,-0.01542806,0.02162279,-0.021607226,0.0516747,0.03707388,-0.029510899,0.088333264,0.078144595,-0.06364097,0.14254192,0.04872157,0.026698047,-0.10804647,-0.037091743,-0.09059285,0.0022324899,-0.060587157,-0.089845456,-0.025596539,-0.006153245,0.05251387,-0.019411013,0.055772576,0.05936445,0.002837655,0.013798624,-0.018919725,0.02202503,0.05787527,0.015384822,0.061022103,0.045548182,-0.005045419,0.06497085,-0.06837775,-0.009074659,-0.013397428,-0.005853006,-0.019654963,0.0639327,0.007470239,0.005042918,-0.031126311,0.05924509,-0.058183365,-0.022673095,0.0045885756,-0.07250756,0.030148642,0.09813435,0.074885555,0.030759396,-0.10126139,-0.037875216,-0.030292636,0.028162083,-0.0020659175,0.00043053646,0.04105793,0.070437424,-0.04092134,-0.02851378,-1.6286013e-08,-0.03146409,0.007156312,0.0068191625,-0.028616693,0.05262884,-0.030109039,-0.025986427,0.032929048,-0.011724115,-0.048560724,0.08718452,0.017533131,-0.029734751,-0.043747574,0.03598983,0.0037778094,-0.04160651,-0.012548587,-0.05793636,-0.0035027834,-0.055176243,0.084634796,0.00975249,-0.03873327,-0.065581895,-0.0042329626,0.08466699,0.11638472,0.00037538836,0.03533921,-0.03539701,0.065038584,0.0068405257,-0.06276466,-0.0052818363,-0.045621373,-0.015874207,-0.008346145,-0.04133628,0.036843553,0.013158636,-0.053220596,-0.033970702,-0.03726783,0.0402523,0.026873052,-0.14011002,-0.027284224,0.020404411,-0.054833476,-0.0038462216,0.046597518,0.02549447,-0.0005032588,-0.020258581,-0.045372177,0.06337572,0.020639354,0.060031973,0.012874348,0.05348525,-0.08852246,0.019652244,-0.07536573]	2026-05-22 12:21:03.638771+00	2026-05-22 12:21:03.638771+00
646821db-5b79-4bb6-bd6f-db0a57e06c9a	00000000-0000-0000-0000-000000000001	faq_agent	country_rule	org	\N	faq_ports	{"answer": "Common ports of loading include Cochin Port, Chennai Port, Nhava Sheva (JNPT), Tuticorin Port, and Vizag Port. Port selection depends on cargo type, destination, and shipping schedules.", "question": "Which ports do you use for export?"}	95.00	seed	1	2026-05-22 12:21:03.643857+00	\N	[0.009701797,-0.058037654,-0.08606071,-0.029821187,0.04853112,-0.0007256123,-0.09691419,0.023494352,-0.065103635,-0.0063332133,0.042293448,0.016890623,-0.060697295,0.0033662023,0.01489548,0.0018985297,-0.0191242,-0.07716354,0.045172445,0.040770303,-0.032203652,-0.0015565963,-0.02903961,-0.12653196,0.007866162,-0.04754954,0.05541763,0.058363795,0.003907411,-0.07816406,-0.14261548,0.008680277,-0.034384906,0.043188404,0.0020020555,0.0023199327,0.08219143,0.0026966445,-0.038980648,-0.048986394,0.060861755,-0.018480385,0.038465213,0.021264952,-0.019082218,-0.06370013,0.030784817,-0.009070954,0.048617445,-0.015740465,-0.0118180625,0.027097227,-0.12225681,0.049845606,-0.004417635,-0.098408826,-0.048591964,0.023743011,0.018516293,0.06507749,0.04838651,-0.015016506,-0.02561144,-0.009220381,-0.041061297,-0.052010097,-0.019657347,0.05911409,-0.066904865,-0.061693028,-0.164068,-0.0113072125,-0.12526521,-0.048883688,-0.01152646,0.001768081,0.054253414,-0.016657235,-0.036270395,-0.017098268,-0.059774306,0.07400926,-0.095413916,0.025785523,-0.004255427,0.06159668,-0.026248904,0.019375686,-0.03561184,-0.021632262,-0.029000828,0.008718254,0.0338535,0.06873563,-0.07881312,0.057021134,0.07580963,0.051210057,-0.02492301,-0.035353743,0.04442734,-0.009838361,-0.009794698,-0.047449518,-0.07343613,-0.041525234,-0.006100211,0.012164535,0.02133642,-0.029155908,-0.036908574,0.0640948,-0.12257386,-0.061851766,-0.039677184,-0.0046516787,-0.10148147,-0.028664911,0.022011824,0.02984458,-0.042216167,-0.010516725,0.08969775,0.055207323,-0.06437374,0.03287851,0.06849955,-3.8501944e-33,0.013537451,0.00073163485,-0.088710524,0.0060808663,0.0280715,0.044305403,0.02456218,-0.021235868,0.023884285,0.01733406,-0.082127675,0.05403247,-0.09550124,0.10306422,0.050544705,-0.04037481,0.032218684,-0.0145480195,0.012516429,0.008180917,-0.024271317,-0.061960682,-0.037189685,-0.00571298,0.1197112,0.008552266,0.016324222,0.020111242,-0.012467955,0.013091342,0.038378425,-0.0063142404,0.054295223,-0.009343894,0.012082869,0.0067005856,-0.07648518,0.024632368,-0.011770485,0.032903716,-0.08675973,0.037793115,-0.075252466,-0.0035205097,0.048197605,0.010664771,-0.021858314,-0.022888236,0.055956885,0.024927977,-0.03361763,-0.012171711,0.02902769,0.0451183,0.03455868,-0.0074403067,0.04027028,0.009525983,-0.008274202,0.042946562,-0.033021342,0.08075617,-0.018138113,0.01913763,0.03535644,0.081155024,0.019669987,-0.0005164995,0.006734802,-0.019072633,-0.046311565,0.015965281,0.12317623,0.01824418,0.022928642,0.07510558,-0.06335382,0.047717888,0.018071428,0.015331822,-0.11050644,0.052699815,-0.11561333,0.038294237,-0.015520936,0.0028803064,-0.04720341,-0.009459923,0.06550276,0.05034786,-0.06304133,0.07221127,0.066178426,-0.052458648,-0.05282543,8.703429e-34,-0.049534097,-0.029465033,-0.02046124,-0.058048334,-0.06958403,-0.021580417,0.10441897,0.0334663,0.026567494,-0.0027449597,-0.03542783,0.011445371,0.09833599,-0.05877304,-0.05236276,-0.061148968,-0.015362859,0.002320731,0.045650363,-0.0569338,-0.028613644,0.03300966,0.14118023,0.037971888,-0.029865395,0.018124279,-0.015636355,-0.057989143,-0.07662643,0.027491283,0.069308795,0.063986205,0.08051566,0.020665219,-0.08517292,0.021429645,0.040529206,0.11146766,0.10967228,0.020417856,0.037106264,-0.014599366,-0.0024291223,0.063005455,-0.08795796,0.021075878,-0.08818326,-0.045044776,-0.010156365,-0.00767615,0.040020257,-0.0077495393,-0.044281438,-0.04093352,0.039499626,0.017632319,0.014544315,0.04643922,-0.025940007,0.053716168,0.058674995,-0.012616551,-0.03594976,-0.03298084,-0.03925416,0.08429683,0.06677244,0.08370601,-0.017599493,0.062314954,-0.02471113,-0.0055407495,0.028393162,0.041063055,-0.04764485,-0.018347148,-0.032525882,0.0065263556,0.008586654,0.0818143,-0.053790182,0.08474333,-0.04937562,0.009455168,0.071104474,-0.05853345,0.02781986,-0.053609226,0.08181482,-0.07161875,-0.024917325,0.012617028,-0.033644512,-0.005400052,-0.019934498,-1.5145345e-08,0.014407258,0.02324698,0.048668962,0.026058268,-0.115935236,0.008469106,-0.0015739365,0.048124112,0.09810028,-0.026944054,0.015628159,-0.022814855,-0.08400057,-0.005933344,0.06598372,-0.0040600155,0.06480194,0.022252558,0.007661556,-0.07901715,0.033519078,0.01036354,0.054755844,0.025750343,0.027937168,-0.06713817,0.07340925,0.023410406,0.013291354,-0.06914724,-0.022335716,0.015238802,-0.046658322,0.029408257,-0.033147424,0.008723113,-0.03127383,0.0075614,-0.0056181964,0.09776157,0.018930312,-0.07587684,-0.04717075,-0.06669642,-0.007303595,-0.025124729,-0.06680603,0.0023578708,-0.010407192,0.057988085,-0.034513187,-0.045036905,0.08251548,0.0044843433,0.068707004,0.04396288,-0.1176377,0.015597504,0.011858455,0.02210562,0.007090487,0.14607246,0.047423866,0.044447523]	2026-05-22 12:21:03.643857+00	2026-05-22 12:21:03.643857+00
58b70bed-b60d-45bc-a3b3-020c0d7bfad0	00000000-0000-0000-0000-000000000001	faq_agent	country_rule	org	\N	faq_lead_times	{"answer": "Typical lead times: domestic procurement 2–7 days, processing & packaging 1–5 days, documentation 1–2 days, customs clearance 1–3 days. Shipping transit depends on destination country, freight mode, and shipping line schedules.", "question": "What are your standard delivery lead times?"}	95.00	seed	1	2026-05-22 12:21:03.648869+00	\N	[0.0106749255,-0.017205687,-0.010001971,0.03642815,-0.022518743,0.0052035563,-0.119300716,0.013442746,-0.028185884,0.019483205,0.050265316,0.0057704807,-0.035383463,0.01826312,-0.00988784,-0.06402157,0.074429326,-0.100180835,-0.012844884,-0.0016706785,-0.0011302682,-0.015071922,-0.008531392,-0.005505943,0.013048277,-0.044913724,-0.053730622,-0.0030218626,-0.03139969,-0.04764382,-0.038723707,-0.073189996,0.03912774,0.015411539,-0.014724685,0.032485355,0.047955636,-0.058674358,0.032496892,0.008600809,0.07370739,-0.014373903,0.0169424,0.08324676,0.035999082,0.00023895601,0.01695554,0.014372991,0.012638558,0.048750825,0.042988297,-0.0030017118,-0.070793696,0.038878635,0.00881815,0.037131794,0.018156348,-0.0325368,-0.011339433,0.0043801432,-0.09889563,0.002990148,-0.086150676,-0.005374137,0.003906179,0.030767482,-0.0017458621,-0.044257957,0.00527228,-0.0140060345,-0.04101598,0.008146759,-0.041207623,-0.0018206729,0.011020346,-0.0128438175,0.06376129,0.0067980895,-0.078168124,-0.0817044,-0.02308652,0.025889818,-0.011344533,0.049127683,0.02565622,-0.02438205,0.062027473,0.20729576,-0.01383684,-0.04002954,0.0859325,0.016309422,-0.068696156,0.04723616,-0.08174865,0.023655338,-0.026164364,0.00071493257,0.039374806,0.012762593,0.055513557,0.007175435,-0.042878255,0.019406023,0.014215134,-0.017403282,-0.036802474,0.00320159,-0.090087,0.047378115,0.006983617,-0.0010295525,-0.010078849,-0.063224725,0.026460903,0.026713151,-0.037585694,0.009335737,0.12146253,-0.045276187,0.03264474,0.08063149,0.060875796,-0.09967432,-0.06071929,-0.0012718267,0.056303337,-2.2570878e-33,-0.08433594,-0.026966266,0.029951952,0.024150489,-0.0008213074,-0.03224719,-0.043752782,0.004913375,0.11666079,0.02324818,-0.056982875,-0.038051296,-0.045097142,-0.057066225,-0.08902633,0.02010681,0.079460196,0.077148356,0.027141562,0.0055364487,-0.043047786,-0.14760989,-0.06417044,0.047094155,0.106017865,0.027840408,-0.038584467,0.04602651,0.04458674,0.0120839095,0.08905897,0.002502494,-0.023523184,0.032718815,0.003491299,0.055676553,-0.04213397,-0.009969542,0.049891584,0.0550875,-0.026478441,0.018099686,-0.032837506,0.058741827,-0.023520343,0.038015626,-0.033897035,-0.10084857,0.0015817558,0.020623112,-0.114124574,0.013499109,0.0609503,0.022407807,-0.019739462,0.019017568,0.1128541,-0.088398,-0.035243455,0.063571334,0.06680509,0.079930395,-0.027758714,-0.027998326,-0.036385823,-0.019196479,-0.01722144,-0.014399048,0.040678896,2.2880542e-05,0.033859715,0.024843203,-0.055871267,-0.09147058,0.0593467,-0.01952986,0.123605065,0.024010599,0.09589521,-0.041905783,-0.021489194,-0.00083038886,-0.015049331,-0.01821095,0.013311132,0.052851126,-0.019226683,0.008268278,0.004209833,0.0016244424,-0.018394053,0.0013348825,-0.00065014075,0.0076768594,-0.041743807,2.6111232e-33,0.025512064,0.039688155,-0.020861782,0.10628241,0.038464744,-0.012306946,0.0037608538,0.08906098,0.1441789,0.08538644,-0.0391771,-0.043652296,0.08524713,-0.016707024,-0.007123396,0.011733522,0.12337427,-0.07748633,0.046809983,-0.053529147,0.018034311,0.02886593,-0.039166424,-0.013868715,0.051985886,0.021192394,-0.017847553,-0.034186155,-0.08523084,-0.08755417,-0.07037516,-0.046518814,0.0035179064,0.044751912,-0.08368673,0.046044156,-0.02258856,0.12576199,0.060109288,0.08573408,0.01870194,-0.0152204,0.04312252,0.049760662,-0.074996784,0.02034462,-0.015921881,-0.06394727,0.025394302,0.091435224,-0.11506138,0.024934443,-0.049539022,0.023153257,0.021527523,0.024322728,0.042371962,-0.07469092,-0.040275507,0.020030277,0.011988679,0.03723546,0.020282278,-0.0058977315,0.027313896,-0.044246167,0.11301887,-0.07129443,-0.00043193257,0.04696586,-5.6668596e-05,0.011549528,-0.062338237,-0.052018687,-0.12661004,-0.06308153,0.052177887,0.01728241,-0.028048132,-0.005386621,-0.006712667,-0.0043857736,-0.030512426,0.059256684,-0.065493554,0.002543187,0.14218652,-0.036913548,0.022834891,0.014955578,0.053316105,0.05270068,-0.029723052,0.032091204,-0.0718848,-1.39465355e-08,-0.0020814307,0.06534036,-0.039876014,-0.046110902,0.10351614,-0.0453013,0.054399297,0.021942202,-0.031891856,-0.026932033,0.07137927,-0.009348146,0.011687622,0.035875853,-0.010443882,-0.01897677,0.010222508,0.0028137981,-0.053796828,-0.12554803,-0.020895155,0.066044606,0.047245547,-0.111011565,-0.013859624,0.041098356,0.031509195,0.06368719,0.02414479,0.00043026442,-0.003241507,0.047140438,-0.02942679,-0.04869955,-0.07312866,-0.015408258,-0.036639847,0.036945328,-0.009574204,0.095293,0.045472015,-0.019554755,0.0022888999,0.027902722,0.002124816,0.0070936102,-0.12300175,0.051212274,-0.08010108,-0.013436494,0.04314645,0.010313675,-0.017318508,0.012410758,0.049412146,0.04770915,0.030832816,-0.062296685,0.02766808,0.011896897,-0.037566595,-0.08350368,-0.025201421,0.030138826]	2026-05-22 12:21:03.648869+00	2026-05-22 12:21:03.648869+00
b2949f5c-26fc-48b1-9652-f52cb9446adf	00000000-0000-0000-0000-000000000001	faq_agent	country_rule	org	\N	faq_countries	{"answer": "Primary export regions include UAE, Saudi Arabia, Qatar, Oman, Kuwait, Europe, United States, and Southeast Asia.", "question": "Which countries do you export to?"}	95.00	seed	1	2026-05-22 12:21:03.65376+00	\N	[0.08687346,-0.048044153,-0.041622933,0.012401317,0.11683429,-0.023022173,0.021093715,-0.043566648,-0.016117794,-0.0048111635,0.038031258,-0.08263825,-0.046054594,0.05922223,-0.025706086,-0.04011127,-0.049812168,-0.018692493,0.0030866507,-0.026809445,0.0066809044,0.007863426,0.03478761,-0.02596712,0.08753722,-0.059785437,0.028475164,-0.032228123,0.008616265,-0.033547863,-0.10616359,-0.003741567,-0.067449614,0.057628725,0.053834725,0.028021995,0.034450546,-0.045364447,0.046872526,-0.018417109,0.038744938,-0.02405711,0.071330264,-0.046990104,0.03640807,-0.0030087384,0.077193454,0.062415194,0.008690222,0.022243036,0.09102244,0.08002164,-0.11617852,0.008136921,0.030750122,-0.0066959336,-0.016817287,0.0010336477,-0.008824691,0.080974355,-0.048271067,-0.038311534,-0.03487687,0.009339196,0.024134817,-0.014474843,-0.050238125,0.105072126,-0.16571447,-0.06326697,-0.08566444,-0.05697195,-0.066186436,0.04668755,-0.03190647,-0.09256213,0.059797302,0.009106515,-0.06575113,-0.036545537,0.023632245,0.08021323,-0.055260807,-0.03949467,0.03999076,-0.021534856,-0.013755976,0.046777833,0.0059102797,0.0476805,-0.04140033,-0.025220616,0.07214965,0.09157276,-0.09808721,0.04309029,0.13014355,0.053612605,-0.0044476558,0.016713705,0.066619225,-0.015894117,0.035693858,0.009282862,-0.080186814,0.014662654,-0.095720276,0.020518988,0.034980576,0.006300245,-0.077561095,0.08533226,-0.06696213,-0.05062628,-0.032811612,-0.044586983,-0.011508176,-0.06752233,0.06162778,-0.020521384,0.022952728,-0.004006361,0.04420759,-0.0010934016,-0.068075486,0.043873303,-0.075410165,-5.867315e-33,-0.015987001,-0.06630922,0.036606625,0.031701185,-0.08468218,0.021507692,-0.006948201,0.011873839,-0.022078067,0.035611767,-0.045776058,0.064237446,-0.054126155,0.11570202,0.0908612,0.059625972,0.04764741,0.03007932,-0.00058316113,0.08949504,0.042924315,0.0052068075,0.004481774,0.09487217,0.021318587,-0.0025951036,-0.055514436,-0.059363645,0.019956002,0.031725932,0.020013383,0.01799102,0.017525503,-0.07734289,-0.037312362,0.0068976446,-0.025709884,-0.0020761276,-0.06133216,0.04755455,-0.044056084,0.007706761,-0.02045608,0.03843782,0.07954085,0.017169105,0.011725138,-0.01691678,0.034023345,0.020427529,-0.07677235,-0.005870082,-0.008435462,-0.086470574,0.060673542,-0.03509874,0.013564749,-0.044420913,0.003961117,-0.0056031556,-0.04995946,0.013531619,-0.0005296722,0.004007768,0.074361525,0.060115557,0.008166671,0.019381369,-0.05413105,-0.053000778,-0.0106151095,0.03730237,0.072105415,0.031308815,0.057495195,0.06885177,-0.0023956345,0.07004611,-0.00073026295,-0.0997837,-0.04665004,0.003646236,-0.09195627,0.0026409193,-0.017542886,0.039562207,-0.064852685,-0.08681579,0.048035767,-0.02489828,-0.08825394,-0.0040742997,0.02538222,-0.05710924,-0.07857767,2.686209e-33,0.014603016,-0.017155197,0.006193431,-0.033113826,0.018183494,-0.02791599,0.0387907,0.0956702,-0.024784977,0.05806164,-0.06962738,-0.044461533,0.07848466,0.059222065,-0.012971125,0.004902834,0.048015244,0.05216866,-0.009444343,-0.07836529,-0.013700049,0.021729026,0.045826264,0.08327012,-0.02827296,0.014002707,-0.07697839,-0.04089428,-0.017588275,-0.060018063,0.02664293,0.07566281,-0.036970496,0.04476375,-0.1294862,0.042744868,-0.107205935,0.044772323,0.093466274,0.07788253,-0.01742091,-0.04098482,0.04088408,0.119333304,-0.087683864,-0.018722912,-0.043584764,0.02873616,0.052669574,-0.09396733,0.07423789,0.08322836,-0.033906173,-0.078390755,-0.0029899233,0.03206861,0.00092196494,0.04249641,-0.016063891,-0.11399327,-0.0071139866,0.073015116,0.02376475,0.0004151673,-0.040541526,0.012263913,0.039504882,0.07992561,0.01996186,0.013276078,0.040095847,-0.024613544,-0.040556464,-0.014491471,0.017837392,0.0009462543,0.047874663,-0.03195199,0.0034478093,-0.007923111,-0.030824712,-0.02897543,0.05851524,0.049768165,0.009280022,-0.070661664,0.0070337863,-0.074789986,0.1027542,0.029242175,-0.05865289,0.055397693,-0.009747726,-0.08287431,-0.026227081,-1.6248109e-08,-0.011990562,-0.025784276,-0.025766494,0.035450656,-0.1348868,0.0027667773,0.010922649,0.06621409,0.020036664,0.019874565,-0.0044399416,0.0012351674,0.016912345,-0.04381268,0.02807601,0.032405697,0.03263294,0.1243497,0.0011460523,-0.048101496,-0.042213403,0.049353432,0.07560655,-0.020479517,0.016425228,-0.049343366,0.018947136,0.040570058,0.07453331,0.01159727,-0.015874088,-0.0025781535,-0.06486632,-0.0031506717,-0.055789176,-0.06680357,-0.016087037,-0.053915795,-0.028752863,-0.06129259,-0.014159588,-0.023628274,0.009509414,-0.0015452646,-0.06357135,-0.10400998,-0.057880603,-0.030684412,0.038384628,0.03451489,-0.08616519,0.011282392,0.025522647,0.016554782,0.042164307,0.0066104024,-0.036073007,-0.055349875,0.039198603,0.04942282,0.038980946,-0.0010706671,0.039800745,-0.0134077165]	2026-05-22 12:21:03.65376+00	2026-05-22 12:21:03.65376+00
e516241d-ba69-47f9-9fa0-8f79ebbdab88	00000000-0000-0000-0000-000000000001	faq_agent	country_rule	org	\N	faq_certifications	{"answer": "Certifications include FSSAI, APEDA, MPEDA, HACCP, ISO certifications, Halal certifications, and Phytosanitary certifications. Requirements vary by product category and importing country.", "question": "What certifications do you maintain?"}	95.00	seed	1	2026-05-22 12:21:03.662553+00	\N	[0.025167746,-0.019453544,-0.0059477645,0.05993672,-0.014570913,-0.028410494,-0.0076576234,-0.010471124,-0.060428735,-0.044015158,-0.035419382,0.004171197,0.00796187,0.05018749,-0.08787546,-0.01733444,-0.037560057,0.0393189,0.07570094,-0.1251292,-0.10103235,0.03431064,-0.007874996,0.02126766,0.012196561,0.0060515306,-0.012943643,-0.017463828,-0.013863626,-0.11017237,-0.03882391,-0.08443058,0.0115758255,0.0053331656,-0.017870527,0.045150075,0.087593436,-0.023607079,0.03530342,0.02164246,-0.01829878,-0.04640058,-0.02751644,0.0019133014,0.011111808,-0.010228112,-0.0032539854,-0.08425682,-0.016043158,0.027241005,-0.012190547,-0.073296435,0.004537267,0.021013163,-0.044399373,-0.03131013,-0.0015843464,0.044278864,-0.02598196,0.010694151,0.04835405,-0.017158624,-0.08216518,0.0674154,0.03501463,0.038936578,-0.07527838,0.09388087,0.057120927,-0.008412032,-0.06781764,-0.041464616,-0.033507798,0.065225795,0.07291404,-0.0028634504,0.025700906,-0.04801815,0.0827281,-0.04411453,-0.02094564,0.06544845,0.00031609595,-0.013547851,0.08979497,-0.049726136,0.014212528,0.036382806,0.016679393,-0.0011972304,0.16064994,-0.071941294,-0.011318426,-0.017423663,-0.054247126,0.011886152,-0.037448097,-0.029838258,0.04904711,0.015383286,-0.020144125,-0.0479673,-0.06264537,0.0317492,-0.0110957455,0.028871927,0.020141082,-0.044047445,0.04545197,0.03073426,-0.018937422,0.0921896,-0.10235598,-0.01176579,0.00814067,0.086069025,-0.012065531,0.052891336,0.09441452,0.053991403,-0.07430335,0.086180404,0.070823535,-0.0778082,0.027550414,0.011493224,-0.011519658,-5.817917e-33,-0.019387474,0.060182523,-0.023092993,0.10855355,-0.0074553136,0.012616334,0.03179673,0.022163995,0.0054908968,0.050394952,0.08161678,0.1539958,-0.09849152,-0.008881423,0.07223301,0.0319625,-0.040765367,0.03857589,-0.04839251,-0.002237653,-0.022248486,-0.012380441,-0.015565574,0.07967483,0.06476518,0.02021868,0.038754527,0.06914738,0.01542069,0.028372211,0.0429298,0.015119541,0.03957848,-0.022319114,0.023134533,0.06969424,-0.027600067,-0.00980854,0.043327622,-0.055842035,-0.06497365,0.012074501,0.055465892,0.0008842209,0.042108405,-0.033904787,0.053983726,0.021495333,-0.016254323,0.021891253,-0.029528165,-0.063678935,-0.069789216,-0.068833366,-0.020057037,-0.057424646,0.022049975,-0.030431744,-0.08120262,-0.01387887,0.003950688,0.01792916,-0.11702477,-0.013241957,-0.00734421,0.025940489,-0.03632891,-0.038688254,0.0481289,-0.035529215,-0.12169442,-0.024780467,0.0021298062,-0.04349089,-0.021382518,-0.06767832,-0.08092426,-0.011706172,-0.019032253,0.012689578,-0.006672411,0.08140207,-0.0045377472,0.033185862,0.081370674,0.0010946166,-0.00038650667,0.028651016,0.020616017,0.06201064,-0.047690667,-0.004231406,0.07107042,0.085539535,-0.061742887,3.421382e-33,0.005717706,0.005660717,0.014474728,0.11149261,-0.009307131,-0.021384079,-0.004902931,0.045721255,-0.026140116,-0.026212664,0.016819855,-0.002631488,0.0105163045,0.041505437,-0.07064749,-0.06857578,-0.14148672,0.030410549,0.020503718,-0.050446056,0.07338762,0.0638729,0.011315605,0.102725275,0.019445587,0.02144074,-0.124868765,-0.016670516,0.03679018,-0.029554216,0.0063611204,0.015693659,0.032587178,0.028922148,-0.043228824,-0.05804133,0.0106764585,0.0056660287,0.009915508,0.10673571,0.04325999,-0.02496977,-0.02242477,0.033434726,0.049596217,-0.042861458,0.020176578,-0.014112981,0.020521753,-0.059422057,0.017369093,-0.065462254,-0.060831986,-0.029189412,0.016474491,0.078480385,-0.051932644,0.017586127,-0.06796774,0.016325979,0.0738512,0.04621551,0.027639667,0.09896672,0.02675638,-0.027048254,0.0775706,0.10861552,-0.0902961,0.041552246,0.006812449,0.037327755,-0.023607548,-0.1148443,-0.09092566,-0.06204964,0.010598568,-0.06099603,-0.053207234,0.031118486,-0.09954199,-0.05026209,-0.022440895,0.054850236,0.08845096,0.036086537,0.022448208,-0.13152628,0.017840289,0.02229992,0.0009784526,0.015541656,-0.009193397,-0.07034099,-0.025536526,-1.5414855e-08,-0.014340382,0.045435734,-0.047278576,-0.03819986,0.0005634407,-0.01657751,-0.036409818,0.029038887,-0.012826226,0.0059554204,0.0388561,-0.05484795,-0.019253176,-0.041784365,0.035182614,-0.023048285,0.04844255,0.1374025,-0.03223524,0.016884388,0.04330695,-0.019723948,0.05106643,0.014601713,-0.087083094,-0.032626797,0.0910026,0.10112477,0.002026044,0.07552974,0.0031973168,-0.038812462,0.08903217,-0.061189115,-0.021434689,0.006733459,0.013390254,-0.056210272,0.039847273,0.09167642,-0.07954386,0.021872466,0.032713573,0.062243942,0.020697132,0.005065827,-0.068496175,0.043707717,0.019680431,0.05405397,0.019297408,-0.07999259,-0.018692436,-0.092789255,-0.038517497,-0.0127927475,0.052044652,-0.013210364,-0.08683011,-0.014515179,-0.007875542,-0.09540986,0.036661435,0.039449748]	2026-05-22 12:21:03.662553+00	2026-05-22 12:21:03.662553+00
0a9783c6-3bc5-460a-8d4d-ce5544dc4dc0	00000000-0000-0000-0000-000000000001	faq_agent	country_rule	org	\N	faq_moq	{"answer": "MOQ depends on product category, packaging type, shipping economics, and destination market. TradeOS AI automatically validates MOQ against quotation workflows.", "question": "What is your minimum order quantity?"}	95.00	seed	1	2026-05-22 12:21:03.667329+00	\N	[0.010166458,0.017485747,0.00308425,-0.0011423149,-0.095190935,0.031648964,-0.04932885,0.043397933,0.041159034,0.025288776,0.050218377,0.020815019,0.0016218325,0.0012479029,-0.021956915,-0.021857189,0.07579601,-0.016406717,-0.092349455,-0.016190717,-0.016236136,-0.039146412,-0.0044011124,-0.020043725,0.01420694,-0.030290633,-0.047115356,-0.02419839,0.051925167,-0.12422715,-0.038361542,0.019159384,0.10225316,0.01793765,-0.009744628,-0.08199208,-0.0051687867,-0.11889005,0.051762,0.01672563,0.022487452,0.05002518,0.018484723,0.011804568,0.009710844,-0.004407749,0.026239578,0.0476775,0.027123593,0.018710312,-0.036658086,0.05731966,-0.08401733,0.13098234,-0.021750867,-0.056750882,-0.032068532,-0.02105109,-0.039703313,0.076289326,-0.0069438224,-0.03246748,-0.02420726,-0.010473208,0.060065385,-0.030519424,-0.029518621,-0.028492335,-0.08304196,0.12624097,-0.006576148,0.0051801447,-0.024412382,0.095713876,-0.018585997,-0.04042513,0.07610136,-0.09512553,-0.047340203,-0.020318875,-0.09293614,0.0018494668,-0.052468494,0.013784247,-0.017962892,-0.08100114,0.02706855,0.09807785,0.02538795,0.0047592735,0.01249514,0.06365697,-0.006431164,-0.007962673,0.02417596,0.015310901,0.040445194,-0.033140272,-0.047638245,0.035792004,0.06919923,0.053353082,0.07756763,0.013214538,0.02168104,-0.041804634,-0.07206233,-0.0037985854,-0.030558342,0.04401361,-0.03645491,0.058577087,0.0007819263,-0.063328736,-0.026253818,0.034811046,0.027859278,0.0054782243,0.045792,-0.046381686,0.005445995,0.062497497,0.031385068,-0.051581237,-0.1164513,0.06306245,0.033243854,-3.2036688e-33,-0.011175844,-0.020466767,0.030912537,0.028415658,0.008045984,0.029112086,0.013599988,-0.037744768,0.02786923,0.05328482,-0.020322783,-0.022152808,0.029687548,0.0074867504,-0.007431111,-0.059790615,0.050697215,0.105630346,-0.010955395,-0.030453967,-0.08824899,-0.111754216,-0.043398928,0.017499624,-0.0131136505,0.016291985,-0.011050806,-0.006491116,-0.00039704915,-0.010707348,0.041014995,0.021031195,0.0106444415,-0.054588117,0.030111233,-0.023767747,-0.031884324,-0.029730612,0.06491374,-0.043253724,0.010104045,0.08171171,0.021257492,0.019519044,0.009711895,0.041246835,0.07927449,0.057520874,-0.026883975,0.018652752,-0.103002936,0.023264626,0.026367823,0.03455436,0.0056758774,-0.03784373,0.011538493,-0.11234795,-0.022366352,0.017813286,-0.012996931,0.014637761,0.028746115,0.06301797,0.03466051,-0.026439445,-0.09826159,-0.07069543,0.042744216,0.009920783,-0.00473019,-0.0033561324,0.04124526,-0.07307504,0.07652547,0.03291783,0.11280091,-0.033130955,0.01293218,-0.10034032,-0.04436833,0.047178786,0.026748672,0.06951972,-0.015842712,0.079049915,0.01313521,0.076888785,0.02591904,0.012213649,-0.07245941,-0.049701933,0.025172576,0.015059359,0.010792128,3.424682e-33,-0.045056358,0.046817232,0.023599193,0.072320774,0.088886775,0.0029880193,0.04698252,0.0058369082,0.017145762,0.06956155,-0.03883173,0.032892518,0.08655383,-0.0429088,0.007160266,0.0825077,-0.017307816,-0.03887999,0.11317309,-0.03834711,0.008135725,0.013564522,0.025951166,0.109619915,0.013897438,0.044536293,0.071337484,-0.0505061,-0.097624905,-0.077336565,0.021833044,-0.0981115,0.005243484,-0.013440115,-0.021092135,-0.038057074,-0.0161827,0.06186071,-0.013629812,0.08965998,0.025110187,0.008572072,0.017939795,0.05813472,-0.05113169,-0.083343476,0.058217328,-0.10791007,-0.025158418,0.05290479,-0.058216725,0.05163609,-0.05770732,0.009495683,0.012200365,0.06874962,-0.04233992,0.0695256,0.067266345,-0.006157709,-0.014131169,0.085851826,-0.0342609,-0.009063892,-0.032753572,0.018766476,0.018688118,0.06707076,-0.029262392,-0.03429232,-0.01119288,-0.00023195049,0.16838376,0.011203467,-0.082131915,-0.059269227,0.049694262,-0.022713704,0.004240946,0.016944084,-0.08055912,0.029922832,0.02232936,0.05605906,-0.0607637,-0.0493666,0.08917963,-0.02346627,0.024388954,0.079145536,-0.045173995,0.047077533,0.055410706,-0.046141878,0.017174581,-1.4193154e-08,0.022250563,-0.054483473,0.034783963,0.03217879,0.06487431,0.014440529,0.044307936,0.0001460357,-0.017164959,-0.0016092041,0.0808885,0.06838806,-0.049877744,-0.024929512,-0.0034193823,-0.031726953,0.0098860515,-0.0727649,-0.06625556,-0.09991172,-0.024000356,0.079515345,0.088549316,-0.053427894,0.0030953118,-0.003157802,0.12634437,0.04737871,0.020076966,0.025949905,0.055993825,0.08471492,-0.030006431,-0.036748387,-0.06374032,0.02633364,-0.1284312,-0.0110036535,-0.035316955,-0.08274241,-0.08628393,-0.09326168,0.007063389,0.010856899,0.03905129,0.015416179,-0.1651326,-0.053766582,-0.024286494,-0.016893566,-0.017517164,-0.030276343,0.059209228,0.037038866,-0.009147355,0.032234162,-0.024915703,0.015948644,-0.050072968,-0.048515204,0.021503963,-0.009984322,-0.047302447,-0.0713295]	2026-05-22 12:21:03.667329+00	2026-05-22 12:21:03.667329+00
44370254-8124-49a6-a1db-62ed39427345	00000000-0000-0000-0000-000000000001	faq_agent	country_rule	org	\N	faq_reefer	{"answer": "Yes. Cold-chain logistics are supported for seafood, frozen foods, and temperature-sensitive cargo, including reefer container coordination, cold storage handling, and temperature compliance monitoring.", "question": "Do you support reefer or cold-chain shipments?"}	95.00	seed	1	2026-05-22 12:21:03.672339+00	\N	[-0.056386333,-0.021407383,0.03832057,0.032640252,0.039891187,-0.020548219,-0.045901865,-0.0077621243,-0.06480076,0.00202617,0.052762587,0.021054713,-0.014078608,0.057934564,0.09489061,-0.0039059154,0.024802916,0.0078479145,-0.06210744,-0.043879017,-0.06814332,0.021540651,-0.06156808,0.062527575,-0.0835908,-0.07317795,-0.077089034,-0.0116314795,-0.07541085,-0.06529038,-0.032711633,0.03263237,-0.01720456,-0.0011321509,0.04021904,0.06845337,0.058360852,-0.026393678,0.029923985,-0.023609415,0.0052191215,-0.0147587145,0.034264877,0.01926408,-0.07131848,-0.09736925,0.031685114,0.02401656,-0.008379362,-0.0058964584,0.0075428444,0.0073267454,-0.007959646,0.06398852,-0.017150363,0.029277908,0.0040012877,-0.12665352,0.00305932,-0.024128627,0.037139874,-0.006190721,-0.028316896,0.026068121,0.042360958,0.006955682,-0.030348748,0.05527,-0.035663515,0.028647749,-0.04647745,-0.016085166,-0.01118242,0.08301625,0.02288187,-0.04581288,0.033362675,-0.10163725,0.043275494,0.012993701,0.0016425533,-0.012713773,-0.011252978,-0.03442844,-0.040212177,-0.03840066,0.065097906,0.08613113,0.0022744213,-0.0069576586,0.012494263,0.01512031,0.09694004,-0.055185124,-0.08216109,0.007070394,-0.02416473,0.08573786,-0.08283429,-0.03772607,0.10368774,-0.00977218,0.031835936,-0.03995441,-0.062845916,-0.016301073,-0.067929834,-0.0063247173,0.031415526,-0.0019966438,-0.08145444,0.06855277,-0.0520562,-0.11571245,-0.10466361,0.046753764,-0.05358032,-0.03213437,0.05451327,-0.05483411,0.028148228,0.056540836,0.09621537,0.015804976,0.008204237,0.001028373,0.015074705,-3.792072e-33,-0.07400384,-0.035526693,-0.012591169,-0.04204466,0.15552905,-0.06600297,-0.029425811,-0.03887247,0.0044713947,0.03964565,-0.034722574,0.05388702,-0.036873046,0.049576905,0.027812373,-0.06644364,-0.061648834,0.039548952,-0.03673158,0.019534448,-0.04399251,-0.06285416,-0.013511853,0.08451402,0.08301661,-0.053246293,0.0345378,0.05442789,0.04986296,0.04021981,0.058647104,-0.025236882,0.029323852,-0.008258874,-0.0077798786,0.02509691,-0.1090704,-0.02765454,-0.034695655,-0.095446415,-0.027359065,0.026386525,0.04046737,0.0989673,0.011447692,-0.02077319,0.030181294,-0.021721154,-0.055407494,0.012291876,0.00042921407,0.034192763,-0.09981782,0.007790481,0.022732364,-0.040999707,0.05954367,-0.05389501,-0.0015980472,-0.060731582,-0.033082686,-0.03579604,-0.020680498,-0.029217713,0.0397695,0.05900172,-0.011704803,-0.03786792,-0.05746,-0.04862749,0.052718896,-0.011555454,0.000560773,0.024286259,0.04267578,0.047744587,-0.0493505,0.052835155,0.04011013,-0.032980535,-0.08161239,-0.011034038,0.02112339,0.08532872,-0.0009806678,-0.026615016,0.019900886,0.07098851,0.07720819,0.06861058,-0.04771667,-0.060654934,0.026626691,0.06538403,0.0015983162,1.3195754e-33,0.005492126,0.027633984,0.08331176,0.0009844153,-0.023955313,0.02187894,0.048335925,-0.06901753,0.12084626,0.012315332,-0.08484462,0.04824307,-0.04549196,0.0034860554,0.05977813,-0.0077370084,0.056303497,0.040625375,0.047628462,-0.014928593,0.016815778,-0.012382705,-0.078991815,0.13934423,-0.010073847,0.047182508,0.009537182,0.0133799715,0.02417133,-0.05255329,0.0040218933,0.046985716,-0.012095227,-0.03762704,-0.09995848,0.024641996,-0.07972322,0.10621411,0.03212231,0.015047344,0.035645917,-0.04120816,-0.027179332,0.104517475,-0.055175778,-0.047808863,0.040459372,-0.059022702,0.047162596,0.01573787,-0.07942729,0.045592245,-0.0017007153,-0.027929135,-0.012581992,0.11806778,-0.030675245,0.011092573,-0.033231847,-0.065977804,-0.032681905,0.035409153,0.07579677,-0.0394837,0.05580042,0.0068960795,0.018996956,-0.07135001,-0.009589596,0.019881638,0.07663641,-0.0342172,-0.027173186,0.03027042,-0.027210796,-0.054511935,-0.043891955,-0.07912887,-0.07019495,0.064027235,-0.035161234,0.012022709,0.027563345,0.013019291,0.056636952,-0.08603259,0.063201874,-0.06888695,0.08606596,-0.020931683,0.019686515,0.0328663,-0.05831922,-0.051596258,0.017976644,-1.706899e-08,0.04069065,0.00797508,0.017095719,-0.012929389,-0.042682834,-0.0560067,0.054238744,0.028738217,-0.03510045,0.072228774,0.03451354,0.085517116,-0.056969263,0.030033462,0.009764802,-0.0026454944,0.0629616,0.051559754,-0.07525056,-0.12350274,-0.010957899,0.0767273,0.05614896,0.04338901,-0.077537365,0.0836388,0.07875985,0.0009953685,0.10886662,0.023738872,-0.008557635,0.030708494,-0.05214283,0.042795096,0.055413757,-0.08005791,-0.07371341,0.0086987745,-0.015659114,-0.0012341518,-0.0008175857,0.019569175,-0.01793238,0.04190796,0.04895839,-0.028505621,-0.20059025,0.024858855,0.0069798343,0.059694678,0.034754068,-0.030994575,0.021900833,0.038502578,-0.020385988,-0.035350423,-0.023773087,-0.0033821068,0.018771654,-0.0077976543,-0.018000873,-0.107605904,0.058758125,-0.0034586587]	2026-05-22 12:21:03.672339+00	2026-05-22 12:21:03.672339+00
ed81a85d-3e64-4a19-a495-fa226fa1b193	00000000-0000-0000-0000-000000000001	faq_agent	country_rule	org	\N	faq_incoterms	{"answer": "Supported Incoterms: FOB, CIF, CFR, EXW, and DDP for select markets.", "question": "Which Incoterms do you support?"}	95.00	seed	1	2026-05-22 12:21:03.677107+00	\N	[-0.053751167,-0.0544578,0.025240751,-0.0935795,0.052982643,0.038924605,0.008722382,0.047857665,0.009978366,0.018346185,-0.010740418,-0.059639044,0.013250804,0.039479982,0.061049145,0.0303759,-0.008858536,-0.040345192,-0.018653758,-0.00476736,-0.09736234,-0.042204168,-0.026766684,0.07908924,-0.005444784,-0.00030105945,-0.023306768,0.021828054,-0.0010329686,-0.08980031,-0.037473246,-0.08385915,-0.015559762,-0.004823465,-0.061885577,-0.0403087,0.0745741,-0.024380388,-0.013155028,0.004742507,-0.04297636,0.0040861224,0.011550659,0.02349996,0.026251275,-0.08411455,-0.026581904,0.0050181025,-0.053203117,0.013321195,-0.008845556,-0.017486254,0.036521878,0.07112394,0.028496766,-0.08824349,-0.10546451,-0.0085076755,0.0052986,-0.0072538084,0.07917526,-0.030100357,-0.013500894,0.059431482,0.016482893,0.088058494,-0.006169794,0.08189129,-0.014038208,-0.047992747,-0.029903902,-0.037909124,0.009809367,0.067955635,0.017292108,0.026792858,0.020554334,-0.039762072,0.09213273,-0.067701615,-0.0075237635,0.047178864,-0.08312129,-0.0037707402,0.059837215,-0.05848089,-0.055551197,0.03357523,0.02808272,-0.0075646783,0.012667166,0.045291305,0.08759338,-0.006280941,-0.03743762,0.084606536,0.03998509,-0.077451184,-0.07638033,0.037221696,-0.028532961,0.056484953,-0.044186972,0.06423252,-0.0014289516,-0.050980367,-0.07881722,0.01549176,0.049388114,0.05004887,-0.019669322,-0.037705854,-0.04420448,-0.006826143,-0.020014208,-0.038922217,0.030570459,0.037544377,0.15335669,0.013125557,-0.07594236,0.008561592,-0.06289409,0.02561958,0.029023252,0.013707057,-0.08347721,-2.058655e-33,-0.059724327,0.012587261,-0.022614634,0.083004735,-0.041108202,0.0019865339,-0.08084962,0.048700243,-0.07911405,-0.06470564,0.009369472,0.09904619,5.8976584e-05,0.08190344,0.08772771,-0.08102269,0.0035572383,0.037747584,-0.092647,0.0066614673,0.0010785358,0.139748,-0.0006785901,0.04635739,0.078680426,-0.05520407,0.066562034,0.05192578,0.0084978705,0.043204885,0.08729248,-0.055221006,-0.05157793,-0.032890406,0.01655743,-0.02708523,-0.084946856,-0.04610258,-0.09352008,-0.063713744,-0.095049165,0.078839734,0.03293113,-0.013602388,0.13113733,-0.006231057,0.029832775,0.040901426,-0.08884344,-0.023370905,-0.058699783,0.07804467,-0.07518257,0.01684971,0.03818008,-0.033891052,0.008891295,-0.032399826,-0.008112637,-0.062694475,-0.050887708,0.020207793,-0.03331086,-0.09725031,0.021717113,0.027543325,-0.04180059,-0.05024635,-0.012540263,0.011111494,-0.015289643,-0.027387947,0.0015437172,0.10019013,-0.07249882,0.016868837,-0.058996096,0.016253924,0.014202073,0.014947323,-0.06811997,0.015455777,0.044875,0.036879506,0.07328428,-0.032616243,-0.033427745,0.030933945,0.062057164,-0.05039145,-0.07011589,0.0038455331,0.07471069,0.02267173,-0.098895624,9.079215e-34,-0.06255707,-0.09422958,0.04764983,0.04940003,0.06810466,-0.012052527,-0.006314748,-0.117270835,0.08439467,0.016352072,-0.018173361,0.0123404935,0.010706246,0.018727263,-0.013548763,-0.021328576,-0.02911157,-0.051671423,0.05802777,-0.0340936,0.06094285,0.066887215,-0.06345631,0.13491337,0.026454166,0.054810077,-0.096862294,-0.03363172,0.011180954,-0.057404608,0.013588389,0.014481968,-0.037157044,-0.038417805,-0.017145291,0.0007208532,-0.032274354,0.046198994,-0.041642953,-0.060493954,0.10767245,0.015917964,-0.006635602,0.07927788,-0.050338615,-0.0028946511,-0.014076603,0.010134769,0.034720995,-0.0030354543,-0.0816627,-0.0360415,0.00035826038,-0.016926821,0.07161478,-0.054594766,0.029186718,-0.010753171,-0.13122377,0.004444677,0.013506543,0.01198932,0.034455582,0.06376658,-0.00092307135,0.006316085,-0.016285533,0.09333823,0.007729935,-0.027411222,0.077050835,-0.079394825,-0.037050508,-0.08350437,-0.017068533,0.024942487,-0.014248031,-0.017316448,-0.017931111,0.01396174,-0.043434482,-0.017559027,-0.005166409,0.046730947,0.0065633664,0.045386117,0.086732544,-0.056193992,0.038029693,0.02297548,0.015182914,0.04009858,0.004475415,-0.0015849224,0.051236827,-2.1578314e-08,0.089070514,0.025122898,0.04923191,0.026063269,-0.02261854,-0.05416159,-0.042632483,-0.032281816,0.0047574067,0.11202444,0.11546911,-0.034893002,-0.0018358562,-0.013125095,0.083126605,-0.02945817,0.06065093,0.07207785,-0.066221364,-0.02550491,-0.022747539,0.06723477,-0.01229093,0.003098737,-0.0031590986,0.021068461,0.022611788,-0.0014389788,0.027841782,0.13804984,-0.06567693,-0.022251667,-0.07854008,-0.024609808,0.010980812,0.022970036,0.0059533403,-0.0098148,-0.015619028,-0.0020097517,0.019075692,-0.012826448,0.048884954,0.017957306,0.021680508,-0.058306675,-0.046650846,-0.037586056,-0.031068401,-0.025643967,-0.062423084,-0.042225927,0.05369695,0.06391094,0.047525007,-0.0046286425,0.005069269,0.008009489,0.0035230687,0.03180234,0.11012636,-0.06943549,0.085864596,0.0649035]	2026-05-22 12:21:03.677107+00	2026-05-22 12:21:03.677107+00
f10dab41-0145-4021-97e3-f8e5cc750615	00000000-0000-0000-0000-000000000001	faq_agent	country_rule	org	\N	faq_new_buyers	{"answer": "New buyers require KYC verification. LC or advance payment is preferred. Buyer risk screening and country sanctions checks are applied.", "question": "What are your policies for new buyers?"}	95.00	seed	1	2026-05-22 12:21:03.682064+00	\N	[0.019247066,0.02301203,0.027621951,-0.032748975,0.0042978018,0.021143567,-0.028244136,-0.019864758,-0.09595866,0.004495238,0.12711926,-0.0041939453,-0.0059799133,-0.026545137,0.044431794,0.0039685564,0.0012343836,0.009764482,-0.038957242,-0.024374986,-0.033206295,-0.03783922,0.009569114,-0.031862088,-0.0027905547,-0.012460334,0.043544255,0.046202745,-0.0037080392,-0.028142218,0.011085733,-0.067467764,0.03909734,0.05227799,0.007916589,-0.005492901,-0.0066561652,-0.13205025,-0.06827991,-0.0431287,0.07396244,-0.06559058,-0.10477478,0.028067695,0.0638921,0.05310402,0.1286598,0.06179861,0.058960598,0.029593809,0.020279981,0.022822483,-0.012884356,-0.004441146,0.019193692,-0.026547654,0.02015509,-0.04463459,0.04094485,-0.07801211,0.091513366,-0.032926917,-0.043787975,-0.007641232,0.0074231196,-0.017530499,-0.06784991,0.09231629,-0.09078091,0.06561134,-0.038210586,-0.021854423,-0.028375812,0.050369807,0.0020284508,-0.10382069,0.017209675,0.010920377,0.027843153,-0.031935137,-0.0044031236,-0.023916047,-0.07458794,-0.07592782,-0.06707149,0.032366812,-0.03331006,0.04558333,0.0069466988,-0.00789014,0.048716355,-0.02472376,-0.013236228,0.017895423,-0.086445644,-0.019600788,-0.002155164,-0.038071197,0.013768953,0.049485,0.018653994,-0.020174123,0.03563654,0.04001946,-0.114104174,-0.008077516,-0.032057848,0.06656616,-0.077801704,0.061954886,-0.03888022,-0.014925476,-0.0018509965,0.009332551,0.06244036,0.015025918,-0.038801853,-0.0048329416,0.05531451,-0.017879006,0.020217834,0.0119522065,0.004951687,-0.060515422,-0.020752847,0.060300812,-0.11080625,-5.5410122e-33,-0.005012799,0.07490488,-0.10274944,0.04926326,-0.057008635,0.07647964,0.028414045,0.052154284,0.0090829525,0.04498776,0.07538949,-0.0042167217,-0.05198555,0.028039072,0.05079822,-0.008960903,-0.080540255,0.072087586,0.073476106,0.036468264,-0.01286105,0.0472434,-0.00584732,0.08153123,0.005145276,-0.0378151,-0.005881147,0.009038463,0.012259003,0.0074981903,0.029649168,0.025657227,0.067781895,0.019152334,-0.06593643,0.03326177,-0.08778212,-0.017259195,-0.04794877,-0.01125141,-0.11833975,-0.0009332281,0.053279694,0.024987515,0.024830919,0.026820155,0.009643505,-0.05617254,-0.066359825,0.06763141,-0.055517744,-0.010413855,-0.05844514,0.02918026,-0.03483526,-0.09005113,-0.024564998,-0.10723199,-0.04558058,-0.12087439,0.028199824,-0.03755818,0.022794336,0.040612802,-0.07828072,-0.023082964,-0.017792374,-0.0072278446,0.020562178,-0.06282273,-0.019863056,-0.030740902,-0.051165838,-0.012309589,0.025677228,-0.039624356,-0.086969584,0.07106237,0.046387997,-0.08589721,0.051716503,0.02645705,0.025581531,0.09094725,-0.010264708,0.0068284995,0.024719022,8.9197536e-05,0.01274819,0.0029589082,-0.08163279,0.046495877,-0.011387365,0.0056454237,0.06810414,2.1346853e-33,-0.00018766578,-0.0242646,0.00079328555,0.013166867,-0.13448317,0.04227287,-0.03378461,-0.016186405,0.1186533,-0.049309064,-0.10560016,-0.016013607,0.10570127,0.013552792,-0.089322686,-0.064373665,0.020248031,-0.008550603,0.13140331,-0.037590135,0.05847564,0.07060366,-0.02210782,0.089429095,-0.045394,-0.021172216,-0.050159797,0.015461041,-0.009644714,-0.11990381,-0.056627374,-0.040936302,-0.0154619,0.03376057,-0.0017447373,0.006481218,0.025817337,0.04617181,0.011049138,0.08370854,0.09373689,0.008396887,0.096296504,0.08800193,-0.0046809497,-0.045156743,0.0555912,-0.06808866,0.044482272,0.017146852,-0.024922498,0.020283753,0.06564189,-0.07390291,-0.033679843,0.07076027,0.111766085,0.010398397,0.028293952,0.108989686,-0.021518577,0.05605691,0.001887196,0.046571396,-0.027677998,-0.07837222,0.03868432,-0.03875029,0.10480853,-0.018682469,-0.013161308,-0.07616752,-0.07186165,-0.040252227,-0.041255362,-0.09574998,0.030872181,0.009152657,-0.009438197,0.006407822,-0.065744676,0.039225508,0.053738873,0.054145783,0.037717257,-0.111128435,-0.0018175507,-0.10079515,0.035857167,0.0031530005,-0.081543244,0.04402316,-0.024613447,-0.013567278,-0.07259284,-1.6207531e-08,0.028876547,0.0014113354,0.040403794,0.054229148,0.024139715,-0.02292591,-0.048745047,0.07290724,0.0060054897,-0.01647095,0.030685732,0.0827253,-0.012423346,0.0017591903,-0.009214204,0.021717438,0.080925904,0.04776339,-0.048993513,0.021783806,-0.016749393,0.11894627,0.03419842,-0.029013786,-0.012103197,-0.0075166235,0.07483247,0.017647013,0.0030315104,0.07672149,-0.043785885,0.05944056,0.0021749916,-0.002804321,-0.04656199,-0.026759112,-0.055752106,0.06427994,0.029064827,-0.06227069,-0.019252315,0.10014916,-0.015921557,-0.0015302574,-0.020254754,-0.022621656,-0.07891548,-0.06615681,0.049515244,-0.043753207,-0.009984576,-0.0014403715,0.06440249,-0.0085337525,-0.024889475,-0.0070422282,-0.01889698,0.03934152,0.0954327,0.0140151875,0.00021827349,-0.016866544,-0.045554664,0.021999009]	2026-05-22 12:21:03.682064+00	2026-05-22 12:21:03.682064+00
ddc9e0db-170a-4b5f-be53-18bf3458cbf2	00000000-0000-0000-0000-000000000001	faq_agent	country_rule	org	\N	faq_documents	{"answer": "TradeOS generates Commercial Invoice, Packing List, Bill of Lading, Shipping Bill, Certificate of Origin, Insurance Certificate, LC document sets, and export declarations.", "question": "What export documents do you generate?"}	95.00	seed	1	2026-05-22 12:21:03.686854+00	\N	[-0.04890793,0.024700781,-0.08841475,0.03234908,0.08213336,0.010971117,-0.07312465,0.023434376,0.008147854,0.034275375,0.00924488,0.011150322,-0.0024534133,-0.04319968,-0.057211712,0.0037511312,-0.06066622,-0.0036613338,-0.0019268651,0.009338128,0.009797439,0.08248841,0.025260001,-0.03659708,0.06702003,0.0050115352,-0.013477245,-0.040986314,0.045725476,-0.07014885,-0.019181639,0.010760204,0.02173967,0.021035496,0.09617034,0.08031997,0.08497144,0.018691018,0.07004035,-0.044619318,0.016647803,-0.023219032,-0.02751186,0.032387864,0.045003187,-0.0006939938,0.023489442,0.037564903,-0.0116461115,0.08309004,-0.04956545,0.023609547,-0.11856112,-0.020805823,0.018168295,0.014917224,-0.02183162,0.023965778,-0.033559237,-0.0010230765,-0.06363571,-0.026671614,-0.09941008,0.02331603,0.0075234827,0.044678055,-0.031345252,0.09870942,-0.029099638,-0.09823171,-0.14248754,-0.027197734,-0.09054269,0.031134654,-0.005907228,-0.052677184,0.018914718,-0.03246855,-0.049160905,-0.05168506,0.008642229,0.060574435,-0.033305768,0.038761824,-0.060230654,0.02167607,0.09916631,0.060122896,-0.029243818,0.054661114,-0.03393311,-0.07107667,0.09313561,0.020014923,-0.1580103,0.06167495,0.09913511,0.008210062,0.12681584,0.010965103,0.0427988,0.014631263,0.11581123,-0.04655992,-0.04522345,-0.045330577,0.023122083,-0.017777696,0.010660296,0.023804063,-0.040172335,0.04719976,-0.13364108,-0.07332663,0.0114645995,-0.03328989,-0.093356766,-0.012695047,0.014451261,0.05839468,0.032602865,0.004856856,0.07576791,0.020585544,-0.12519579,0.011549055,0.04130117,-4.5813636e-33,0.008845551,-0.003032591,-0.05143543,0.10663891,0.04409834,0.007942296,0.035229523,-0.05182686,-0.020522652,0.018848686,-0.03245179,0.10038276,-0.07333357,0.1665487,0.05537502,0.0016411562,-0.020199504,0.0436939,0.025320722,0.025156422,0.008673566,-0.0020798368,0.020877883,0.04011188,0.07167402,0.053298827,0.024135778,-0.036950838,-0.06053725,-0.020796662,0.027842056,-0.015489597,0.07067568,-0.06353069,-0.04273295,0.08344728,-0.084326,-0.026893836,0.0108460635,0.06874861,-0.06875022,0.025706135,0.043120716,-0.0030962958,0.022849152,0.04140257,0.031094346,-0.0030086183,0.0926572,-0.0050966027,-0.022131732,-0.02094829,0.031105598,-0.027802892,0.014241821,-0.05235297,0.044068538,-0.06476007,0.03360587,-0.036820684,0.006599614,0.07974914,-0.028820101,0.028331619,0.025319356,-0.009803492,-0.0035471695,0.00094710494,0.06574259,-0.06138165,-0.06348428,-0.012856704,0.0006478186,-0.09714351,0.059406657,0.03393026,-0.021904757,0.024343591,-0.07778259,-0.039905205,-0.115685135,0.008107405,-0.06340397,-0.07035324,0.024363654,0.07326011,-0.01677752,-0.010983773,0.010531318,0.04110988,-0.018404093,-0.025780413,-0.043243986,-0.03138226,-0.0468292,2.3315626e-33,-0.011951674,-0.081555344,-0.04878826,0.020255273,-0.010863314,0.04915389,0.019377993,0.06348871,-0.08027924,0.027785774,-0.05547501,-0.039374277,0.04148985,-0.009938231,-0.07045082,-0.08129281,0.06417403,-0.0020118302,0.012319429,-0.04829114,-0.047472924,0.046703804,0.062358897,0.0875731,0.101312615,0.022899227,-0.017195653,-0.03089963,-0.03755058,-0.014588777,0.026005393,-0.018370587,-0.00498291,-0.020164646,-0.05896429,-0.050121795,-0.012871819,0.062595986,0.075638816,0.084445365,0.015151446,0.030651035,-0.0313917,0.076935515,-0.07681482,-0.016957892,-0.08539024,0.013733724,0.044730403,-0.036905315,0.10194466,0.033839777,-0.039943285,-0.1091225,-0.0136839375,0.016485535,-0.008220813,-0.017207537,0.018036986,-0.002660062,-0.024246784,0.031149602,0.012759293,-0.0005691822,-0.07072437,-0.024187593,0.008770602,0.053545676,-0.103674434,0.065398425,0.0040280414,-0.0047356696,-0.00090038136,-0.016618086,-0.006115641,-0.022932112,0.002921148,-0.005969907,0.032833267,-0.028247314,0.02541412,0.09092591,0.031673472,0.054685704,0.07880246,-0.09549482,-0.020610768,-0.053484984,0.049994607,0.025909083,-0.036728755,0.050236132,-0.005673399,0.05184769,-0.017084295,-1.474537e-08,-0.06860139,0.015467345,-0.0022964901,0.027923191,-0.06538526,0.04886038,0.028196715,0.03069925,0.019505022,-0.09256139,0.051676102,-0.0960715,-0.09431268,0.0033577646,0.03543699,0.010421968,0.11731175,0.02159556,-0.008802854,-0.08046516,0.0012478264,0.02620794,0.06804712,0.0026298994,0.06571074,-0.014722103,0.015567444,0.011552042,0.054085422,-0.07506574,-0.022560813,0.039625015,-0.059574228,-0.0041231075,-0.0094236,0.021632247,-0.027782084,0.003567669,-0.020459967,0.0035701897,-0.0037422932,0.009683816,-0.026639333,-0.028482419,-0.037096422,-0.07809595,-0.09554,-0.07728308,0.011768783,-0.038508568,-0.0404113,-0.067074366,0.11454474,0.036614448,0.032723367,0.007727517,-0.009830864,0.02591707,0.08561385,-0.029137122,0.05015668,0.042691946,0.05285108,-0.0097232675]	2026-05-22 12:21:03.686854+00	2026-05-22 12:21:03.686854+00
5a64b194-05a3-47c3-afa3-1644f1aae850	00000000-0000-0000-0000-000000000001	faq_agent	country_rule	org	\N	faq_compliance	{"answer": "Yes. TradeOS validates against DGFT rules, ICEGATE workflows, UAE customs requirements, sanctions screening, and restricted goods policies.", "question": "Does TradeOS support customs compliance?"}	95.00	seed	1	2026-05-22 12:21:03.691363+00	\N	[-0.08952772,-0.0012835882,-0.0089771645,-0.055738725,0.06465655,-0.06867438,0.021901216,-0.0027876832,-0.14072956,0.030482138,0.07713814,0.01446932,-0.06271474,0.097624645,0.057501975,-0.006003519,0.055572283,0.052415695,-0.08433627,0.028591083,0.022453964,0.012431276,-0.038991347,0.009581006,-0.054446615,-0.043400176,-0.0036703027,-0.023466125,-0.011894717,-0.036003515,-0.122801594,0.06276509,-0.01728862,0.10190753,-0.00048616223,0.046558872,0.07688242,-0.064176194,0.016808646,-0.025624933,0.0140663935,-0.004873782,-0.030889222,0.028174404,-0.007863543,-0.025405698,0.035042185,0.0061733085,-0.0060627013,-0.012977835,-0.024988893,0.030504696,0.016074564,0.06887521,-0.003286169,-0.0041351495,-0.007152005,-0.018265927,0.024932055,-0.024548603,-0.032098956,-0.08211921,-0.016403645,0.09528021,-0.010760373,0.032877434,-0.061073724,-0.0027711522,-0.061276674,-0.081156336,-0.040390924,-0.034859452,0.014987137,0.04494816,-0.009610164,0.08335951,0.01938084,-0.0041926554,-0.012545383,-0.0994691,-0.00067715626,0.041529365,0.037239257,-0.015267244,-0.0007491457,-0.00089294865,-0.039434317,0.011798329,0.02682418,0.058341227,0.038623802,-0.093757875,0.029091123,-0.03925059,-0.08994827,-0.009718097,0.07892588,0.09440383,-0.03400337,-0.008226307,0.0507284,0.03796807,-0.11778109,-0.02785471,-0.060795642,0.030906716,-0.011519457,-0.0656921,0.007876215,0.10240713,-0.08425423,0.06230594,-0.040929716,-0.08390063,-0.022205327,7.914784e-05,-0.017858274,-0.047407437,-0.012990087,-0.06713993,0.057150852,-0.028746566,0.082128584,-0.08377746,0.0038768058,0.006281575,0.053629875,-3.07221e-33,-0.06598194,0.03560483,-0.035701636,-0.048770748,0.070755295,-0.0131886685,-0.043979205,-0.04166666,0.013818351,0.004282319,-0.14584026,0.092329994,-0.066480495,0.024233945,0.06141598,0.07774312,-0.04526182,0.013726865,0.12874506,0.09968832,0.05746616,-0.15128127,0.00050348416,0.020232864,-0.021460569,0.077896856,-0.018752608,-0.018898882,0.053409807,0.042063925,-0.011805238,0.045599137,0.07041408,0.028608728,-0.014038025,0.06276159,-0.023767399,-0.044031408,-0.014686448,-0.048076693,-0.021874478,-0.003887915,-0.012597391,0.07772492,-0.0040809913,-0.048838843,-0.014642127,-0.026302839,0.045336116,0.016765174,-0.043593228,-0.00081193406,0.01042144,-0.11426135,0.059650853,-0.03905121,0.004125382,-0.01880979,0.040936988,0.070765115,-0.03182875,0.03008529,-0.007537629,0.06327547,-0.0024717848,0.035995785,-0.069982685,-0.039119538,-0.048851203,-0.040623832,0.0076807016,0.04437085,-0.06170079,0.115179375,-0.029781677,-0.004083129,0.05578409,0.07845559,0.073444925,-0.079539746,-0.077422656,-0.013897227,0.062448233,0.12883784,-0.0117289,-0.010940878,0.030563813,0.07063828,0.07958219,0.029936135,-0.029425789,-0.04345994,0.002384072,-0.046887856,0.005716022,5.84899e-34,0.058598883,0.029336335,-0.0036014058,0.0080249775,-0.06268959,0.010891388,0.0042766007,0.054840535,0.11453332,0.025588363,0.0048785605,-0.014522472,0.061649967,-0.028503567,0.031859938,-0.04541732,-0.010580377,0.061950423,-0.043046787,-0.051910557,0.007884283,-0.048652556,-0.030438872,0.049500417,-0.005359323,-0.017631331,-0.12550493,-0.038960762,-0.0062562,-0.0071716495,0.10152519,0.048279956,-0.02706288,0.050961733,-0.022029374,-0.06597655,-0.066604435,0.081639096,0.08247242,0.025369318,-0.008364162,0.04236569,-0.04306494,0.12426065,-0.093096994,0.008641906,-0.04474187,-0.016434235,-0.0010386307,-0.021535251,0.03952012,0.10714298,0.03517876,-0.08033499,0.032057438,0.107565865,-0.031050425,0.037249602,-0.065942384,-0.020496318,0.055691294,0.0098360535,-0.017124183,-0.0663113,0.103087135,0.035689753,-0.0030895283,0.011389419,-0.00016670102,0.05877696,0.10374542,-0.0691327,-0.056883298,-0.04077248,0.047001645,-0.11538041,-0.055397276,-0.027204966,-0.015518879,0.07787767,-0.028095262,0.0034824137,0.032329336,0.03318109,0.07152504,-0.016236821,-0.0018415545,-0.044392113,0.041269172,-0.0121182725,-0.05889014,-0.010872996,-0.070028365,-0.045662522,-0.012550493,-1.456914e-08,-0.008525837,-0.012496134,0.004600989,0.044489447,-0.10967952,0.026899792,-0.007946519,-0.0253518,-0.043631088,0.039632604,0.014377814,0.037099477,-0.053818636,-0.01214076,-0.017158248,0.0188891,0.05770298,0.12035234,-0.07148565,0.03333996,-0.00051164214,0.032358013,0.0233295,-0.003543563,0.044122294,0.038247667,0.027523415,0.005721664,0.063366875,0.025137916,0.023554467,-0.036891907,-0.03814807,-0.003089108,-0.04780064,-0.04741897,-0.05671396,-0.027994908,0.057049938,-0.037271395,-0.07400246,-0.031553783,0.0017065759,0.06687956,-0.007814627,-0.0425132,-0.08011274,-0.03282225,0.021381246,-0.028314961,0.0046982863,0.004265519,0.024548372,-0.028767118,0.02293336,0.0020788242,0.02053863,0.0003227063,0.024504034,-0.04385116,-0.025799448,0.018830359,0.08926803,-0.011857555]	2026-05-22 12:21:03.691363+00	2026-05-22 12:21:03.691363+00
3358734e-8322-4fdb-9197-c09c157743d2	00000000-0000-0000-0000-000000000001	faq_agent	country_rule	org	\N	faq_pdf_ocr	{"answer": "Yes. Supported formats include PDFs, scanned invoices, packing lists, BL copies, LC documents, and handwritten notes (limited support). OCR and AI extraction pipelines process documents automatically.", "question": "Can TradeOS process PDFs and scanned documents?"}	95.00	seed	1	2026-05-22 12:21:03.69508+00	\N	[-0.08596275,0.033968206,-0.12606794,-0.02039442,0.030117529,-0.08810777,-0.011603339,0.027298696,-0.07778019,0.004755998,0.032639384,0.15352668,0.018490965,0.070920505,-0.04684815,-0.08544807,0.027069723,0.01352998,0.026085334,0.0658911,0.0052598827,-0.014558887,-0.0418684,-0.076064005,-0.035977744,-0.007699839,-0.05382019,-0.08802382,-0.0813777,-0.053739615,0.02406494,0.032404788,0.045144908,0.08335746,0.077856675,-0.0020593854,0.062104143,-0.035424102,-0.0044540996,-0.089882344,0.02233111,-0.019376548,-0.062727645,0.054805208,0.03296635,-0.019661661,-0.016944995,0.0183824,0.031930517,0.009770771,-0.12534572,-0.019316405,-0.030411443,0.0733836,-0.0140352985,0.057397462,0.019891897,-0.006068232,-0.053019468,0.009189544,-0.10975644,-0.024534244,-0.055665694,0.08624437,0.06822935,0.11453725,0.032569125,-0.0021004383,0.0064451066,-0.064239934,0.0030589232,-0.0049862526,0.056786735,0.035347793,-0.0016454152,0.028581837,-0.0050281836,0.012278891,-0.012676377,-0.1307267,0.027997872,0.040146925,0.0664041,-0.032357767,-0.06347094,0.016185278,-0.013854974,-0.021398172,0.050716583,0.03209766,0.013035059,-0.010756226,-0.07186113,-0.032289326,-0.06630972,-0.039645344,0.14923021,0.027388172,0.074509636,0.007756225,0.051478166,0.0035527223,0.036984105,-0.11576089,-0.11125546,-0.03164824,0.03630688,-0.029104808,-0.0031914057,0.008357397,-0.06315738,-0.00046831914,-0.039232414,-0.04954279,-0.0068601193,0.01931463,-0.016538313,0.00095591706,-0.062376954,0.056297086,-0.060022697,-0.03418968,-0.0256172,-0.08898689,-0.0100322515,-0.02819687,0.10165127,-2.9332276e-33,-0.047287274,-0.0028056619,-0.017806701,-0.0040416913,0.037837524,-0.005529882,-0.030288147,-0.08688351,-0.02335198,-0.047533453,-0.119545646,0.07523547,-0.026727956,0.09074683,0.03672108,0.046996187,-0.03237523,0.11944941,0.013229746,0.07557061,0.020648126,-0.10457123,-0.026402367,0.0025396363,0.0022571732,0.1125268,-0.034294866,-0.048551068,0.05124711,0.0070046703,-0.027103487,0.08440895,-0.025287854,0.051416114,-0.045015413,0.06767083,-0.029421985,-0.004306346,0.0060027787,-0.06452246,0.061943986,0.005099999,0.048787702,0.039266095,-0.053671774,-0.061950266,-0.027326988,0.009150108,0.04633734,0.02925124,-0.0028171358,0.015751636,0.009314362,-0.060426805,0.10202578,-0.013005646,0.017003564,-0.04001424,0.07041843,0.0030465683,0.01039444,0.04646949,-0.03645612,-0.003081413,-0.017900689,-0.035311546,-0.02719206,-0.006633226,-0.004412905,-0.02151725,-0.04413754,0.006028803,0.011153753,-0.019227982,0.086305805,0.059043188,0.06398392,0.059826016,-0.033684075,0.0050475406,-0.071248926,-0.041386895,0.06926157,0.021885926,0.00042577725,0.09116159,-0.042560734,0.023464534,0.0002590088,0.051851936,0.009728527,0.027844232,-0.08556711,-0.0068855044,0.05017659,7.73441e-34,-0.035723217,-0.07695014,-0.048820306,0.077397645,-0.09763087,0.00960395,-0.018164502,0.03965475,0.03445405,-0.02399415,-0.024932558,-0.04136226,-0.024941992,-0.088160075,-0.043820158,-0.075192176,0.058254834,0.048576392,0.0009233703,-0.02376597,-0.0610834,0.019527107,-0.0015864478,0.086254634,0.093091324,0.0062447106,-0.049902927,0.020913081,-0.011405416,0.05840068,0.07198747,-0.022992363,-0.016684582,0.09842247,0.059883483,-0.07047285,0.0026396576,0.06689374,0.053038463,0.03881205,0.039004445,0.0528024,-0.016484411,0.012043749,0.008412727,-0.023724351,-0.052949797,0.022592776,0.029776767,0.011749651,0.055784926,0.067516655,-0.027551135,-0.08015109,0.013809426,0.065438785,-0.008281822,-0.025611207,-0.062400743,0.028003806,0.009673817,-0.020415198,-0.007688104,-0.08446305,0.036855184,-0.0014596626,-0.0031764298,-0.041346293,-0.044581797,0.04565502,0.120983645,-0.04299511,-0.0046888883,0.0005533268,0.066961624,-0.017549938,0.01209435,0.022183817,-0.052025862,-0.048087265,0.0097147105,0.03300387,0.04809466,0.03832456,0.06453068,0.045346566,-0.06748117,-0.13409048,-0.002185318,-0.075715244,0.051260997,0.0070267543,0.043817926,-0.035691682,0.0008447113,-1.5741973e-08,-0.0251218,0.0029403553,0.03839252,0.017206527,-0.03940728,-0.0073563424,0.052112676,0.06373036,-0.01333294,-0.06278816,0.056301273,-0.098926336,-0.04556624,-0.062251847,0.07252232,0.04096668,0.14487723,0.023120625,-0.0771504,0.0018515558,0.057751283,-0.010918834,-0.013538433,0.05567069,-0.0064578396,0.005967975,0.09181823,0.00853208,-0.00012519934,-0.07419102,-0.029467732,-0.006121305,-0.05814779,0.077118106,0.02233186,-0.06151131,0.03863636,0.009362627,-0.055303678,-0.0011895533,0.0038183667,0.020072177,-0.05301375,0.00072746846,-0.009178026,-0.059594486,0.016240472,-0.071525805,-0.01245191,0.0069491463,0.021946684,0.020566896,0.052950274,0.009906142,-0.036250252,-0.034352694,0.11721471,-0.012857172,0.03710097,0.0411796,0.0065115984,-0.043413337,0.0793855,0.022370724]	2026-05-22 12:21:03.69508+00	2026-05-22 12:21:03.69508+00
a183e743-8de7-40de-a94a-464109b488f1	00000000-0000-0000-0000-000000000001	faq_agent	country_rule	org	\N	faq_tracking	{"answer": "Yes. TradeOS supports container tracking, shipment milestones, ETA monitoring, customs clearance status, and customer notifications.", "question": "Can shipments be tracked automatically?"}	95.00	seed	1	2026-05-22 12:21:03.699676+00	\N	[-0.055681057,-0.042694256,-0.04122363,0.032310244,0.037670635,0.03815378,0.036479685,-0.06807656,-0.09804054,0.02603555,0.061444912,0.03973678,-0.017773012,0.034247793,-0.059042223,-0.0604323,0.034386877,-0.020593433,-0.04567072,-0.041739877,-0.02932002,0.040431485,-0.043036442,0.028847635,-0.0300661,0.00044385812,-0.043828014,-0.0657349,-0.07076181,-0.0095294425,-0.027347777,-0.06761194,0.006466791,0.09399852,0.026119802,-0.0730417,0.029168557,0.008385499,0.07013773,-0.07163486,0.0045161885,-0.032300223,-0.03277613,0.056674022,-0.027673552,-0.04274078,-0.0108915195,0.0501778,-0.06308126,0.0061591305,-0.010513688,-0.026940381,0.070156515,0.036462046,-0.048111342,0.063536726,0.089716114,-0.03475993,-0.023833318,0.029442174,-0.035816938,-0.0280974,-0.0059550125,-0.009341263,0.034557328,0.04871574,0.001329566,0.018528031,0.030181382,0.0028954993,-0.006558196,0.056456894,0.0062421146,0.05691292,0.020441115,-0.019642578,0.009205324,0.020141598,-0.032577347,0.017713081,-0.064640455,-0.01859024,0.0034691582,0.034258813,-0.020934656,-0.0444791,0.0151178,0.09467847,0.011040141,-0.039917305,-0.046696965,-0.014994401,0.04530234,-0.026973836,-0.07695494,-0.030190427,0.05196149,0.04875264,0.064427935,-0.022921724,0.06980226,0.06908654,-0.028060459,-0.020594418,-0.033969626,-0.03931779,-0.033931687,-0.012371435,0.009981997,0.042142358,-0.054986842,0.025616836,0.031158563,-0.06101745,-0.042749953,0.0498278,-0.025711142,0.05024667,-0.039892007,-0.062571764,0.012340573,-0.0065307613,0.0952563,-0.062635176,0.0412789,0.0807448,0.11021614,-3.632751e-33,-0.0070932475,-0.020365214,-0.056436934,-0.07486015,0.023387428,-0.037287164,-0.032085795,-0.027664255,0.072993025,-0.035731904,-0.09447866,0.09259199,0.025708005,0.0716812,-0.020096047,-0.030582609,0.03173484,0.0568272,0.09448485,-0.026044931,0.00084282417,-0.17800352,0.0029601362,-0.036793843,0.1157808,0.036469057,0.0019184572,0.10030323,0.054596934,0.01908577,0.045736812,0.009682593,0.039392978,0.036886696,-0.045534015,-0.021607252,-0.073124394,0.011331538,0.017067228,-0.047267973,0.068367384,-0.018328376,-0.014349012,0.04046276,-0.07800205,0.073413566,-0.020948857,-0.011195374,-0.016221976,-0.009027699,0.018039512,0.008631642,-0.069509916,-0.069985166,0.033848614,-0.0002788262,0.07974088,-0.12167196,0.08504648,-0.03891022,0.03331586,-0.0078333225,0.031219488,0.028666457,0.09705452,-0.06294019,0.038814593,-0.008425755,-0.006867251,0.014589559,0.04196677,0.034762576,-0.023511816,-0.04608895,0.10744673,0.064214975,-0.008152859,0.05649958,-0.046688896,-0.018455487,-0.072249085,-0.0814946,0.07111912,0.019362582,0.046465255,-0.009795741,-0.025825782,0.05957263,-0.05278438,0.019281963,0.05483871,-0.016056504,-0.034527604,0.05052702,0.0061876294,1.920661e-33,-0.0025101043,0.07265723,0.0006967084,-0.0032517677,-0.0419808,0.04028033,-0.005963034,-0.04489681,0.019637128,0.06652941,-0.106923856,-0.053648483,-0.050209645,0.027179852,0.03149445,0.032379467,0.039921388,0.011759644,-0.0043469425,0.016876731,-0.049235433,-0.08928659,-0.043464854,0.0040217713,0.036777444,0.026397344,0.07622152,0.008130852,-0.06082012,-0.017388662,0.027373789,-0.052993532,-0.016997617,0.026606496,-0.03825994,-0.0041915076,-0.050437808,0.14811297,0.11065614,0.07354103,-0.0366103,0.027084455,-0.094384,0.048547354,-0.104415126,-0.0641208,-0.007845072,0.08395227,-0.023602765,0.0079686055,-0.11619557,0.04289096,0.020594595,-0.04797398,-0.022449976,0.17205109,-0.010806095,-0.005802923,-0.008626644,-0.0059812414,-0.058584224,-0.06751556,0.076720305,-0.024123061,-0.012578652,-0.040650852,0.06281549,-0.045223754,0.029271424,0.07727066,0.06215546,-0.025304222,-0.026169503,0.021963986,0.016282152,-0.0711059,-0.016302593,-0.011194554,-0.07828499,-0.061487027,0.026427174,-0.03560313,0.015461069,-0.027151907,-0.05038501,-0.053671937,0.02487492,-0.016784277,0.093641244,0.01398389,-0.009143275,0.035613604,-0.06343211,-0.066799395,-0.051479544,-1.3016999e-08,-0.04494846,9.3017035e-05,0.019681066,0.092898116,0.024060465,0.019781083,0.09261382,0.062207974,-0.045216735,0.0026481398,-0.04607969,-0.052550454,-0.082699075,0.0799875,-0.04186158,-0.020600405,0.09555949,0.010793781,-0.038640656,-0.032742355,-0.022252351,0.017140632,0.057350084,0.039497565,0.02263471,-0.026167389,0.009149219,0.026224712,0.13998383,0.07167805,0.016352441,0.05453578,-0.008585343,-0.012612189,0.0046254555,-0.05295282,-0.023363627,-0.059310928,-0.06932917,-0.04010535,0.019760083,0.014284532,-0.065131634,0.027482778,0.05997032,-0.060700618,-0.091325015,-0.11127683,0.031335674,-0.04995123,0.030352827,-0.0552034,0.06688591,0.06900134,0.027787264,0.023338739,0.038354587,-0.09081889,0.09757719,0.037333846,-0.055187065,-0.012422086,0.06645582,-0.02018864]	2026-05-22 12:21:03.699676+00	2026-05-22 12:21:03.699676+00
99f15b29-8380-451d-909d-319a8449ef44	00000000-0000-0000-0000-000000000001	faq_agent	country_rule	org	\N	faq_lc_workflow	{"answer": "Yes. TradeOS can validate LC conditions, compare invoice consistency, monitor discrepancies, and assist with bank documentation.", "question": "Can TradeOS manage LC workflows?"}	95.00	seed	1	2026-05-22 12:21:03.70362+00	\N	[-0.09705694,-0.019398522,-0.036639914,-0.07240501,0.0071562105,-0.06629119,0.018749973,-0.014389922,-0.01762081,0.023476625,-0.024610754,0.05517938,-0.007879979,0.05649485,0.06867224,0.008516431,-0.007025673,0.0501582,-0.07007057,-0.046556484,-0.0033362955,-0.023239592,-0.11774347,0.09421614,-0.07143228,-0.038662743,-0.043973543,-0.020398652,-0.047835916,-0.023455888,-0.05284273,0.08032336,0.053340413,0.11730638,-0.019429734,0.05714102,-0.018669995,0.011281459,-0.050685294,-0.09374066,0.0063529476,0.0067899167,-0.024084043,-0.009851507,-0.041517094,-0.036384538,-0.030534277,-0.021977862,-0.07452645,0.015843058,-0.039275452,-0.07868153,0.01929432,0.08959711,-0.015213844,0.095476456,-0.012670143,-0.06412662,0.0600391,-0.04528865,-0.07963247,-0.027888251,-0.052273095,0.047025226,0.025305545,0.061454695,0.024429817,0.0072473227,-0.053289555,-0.056342717,0.04533825,-0.080438,0.010724331,-0.010535472,0.032029726,0.09792806,-0.026370052,-0.047830246,-0.024594566,-0.0615538,0.010158407,0.04940908,-0.033412576,0.014699566,-0.03511268,0.01897751,-0.011476415,-0.009965348,0.14277525,0.01038691,0.023059294,-0.047767747,-0.027601207,-0.06676756,-0.0091866385,-0.020936122,0.10446677,0.070683,-0.018498866,0.0009582388,0.03400234,0.055299092,0.05266292,-0.04932209,-0.030862138,0.020809427,0.037991196,-0.004219231,-0.015976151,0.027337182,-0.0946747,0.05047352,0.009949505,-0.06385668,-0.042535074,0.050212245,-0.028294936,-0.0156292,-0.0493362,0.044913486,0.049218357,0.004936995,0.008856478,-0.086151026,-0.014363674,0.013160682,0.010726836,-2.9629832e-33,-0.009632872,-0.009208822,0.017593069,0.046310887,0.09010828,-0.030398339,-0.0050693033,-0.055602003,0.01423208,-0.084648766,-0.08749297,0.16936685,-0.013769473,-0.018357798,-0.013283746,-0.022372782,0.009692485,0.07741081,0.06274922,0.08660717,0.048069455,-0.08035651,-0.03603436,-0.00867769,-0.008419858,0.07309153,-0.04284399,-0.019759646,0.08742227,0.054099966,-0.053493977,0.028334951,0.022138938,0.094103776,-0.0744984,0.07490986,-0.10036397,-0.023048813,0.11950347,-0.043153524,0.0072225677,0.004144483,-0.083391435,0.034919128,-0.024826275,-0.081895605,-0.0397371,0.0017003348,0.03596151,0.008902514,0.0769208,-0.022700075,0.019148475,-0.08591034,0.10378781,-0.031859543,-0.020102307,-0.022678005,0.04846669,0.08521339,-0.026593182,0.08427457,-0.062276147,0.08088405,0.061248884,-0.0063658,-0.09282724,-0.015567198,0.033639535,-0.045217443,0.00032971404,0.063833155,-0.004826026,0.13219066,0.042951517,0.0012193748,0.08936219,0.054267067,-0.027442396,-0.005963901,-0.031126698,0.033386137,0.06657113,0.14388834,0.094073325,-0.009259438,-0.016895454,0.045411114,-0.08303853,0.029488353,-0.004657234,-0.040079564,0.06627966,0.028192252,0.0110613825,8.391811e-34,-0.024166962,-0.033463072,-0.009355291,0.024534173,-0.049528282,0.0031810747,0.009666261,-0.03745106,0.10230584,0.02557627,0.03541592,-0.048933804,0.020552577,-0.0450528,0.020418793,-0.05872024,0.05445032,-0.0055722008,-0.03326826,0.0014461157,-0.011840268,-0.012632948,-0.044105724,0.049238246,0.03970919,-0.020918693,-0.099918626,0.012491633,-0.015731702,0.0022534004,0.027942883,-0.031329565,0.032504074,-0.0021911927,0.0789366,-0.09601619,-0.11374549,0.08453727,0.07372226,0.04173054,0.025452921,-0.057277378,-0.023354648,0.016839039,0.00014578656,0.035315454,-0.043891612,-0.0508755,0.053847134,-0.045600813,0.05024347,0.057410188,-0.026859382,-0.05660533,0.015755475,0.061088353,0.036286544,-0.014560341,-0.06370182,-0.054202642,0.004589583,0.013911628,0.04994731,-0.03602106,0.087580286,0.014197329,-0.018267598,-0.05382387,-0.09273285,0.016845413,0.096136004,-0.021028746,-0.065770134,-0.026355417,0.08300313,-0.10606468,-0.057545453,-0.085155345,0.014965679,-0.022093736,-0.046659846,0.038142625,0.08830469,-0.042392742,0.016061513,-0.01302307,-0.037292104,-0.039414454,0.030594952,-0.013059209,-0.0352779,-0.07108831,-0.0037063656,-0.032075882,-0.0020386782,-1.5802215e-08,-0.002866988,0.015324217,-0.004615557,-0.0068490324,-0.08516342,-0.022800542,0.0063340426,0.072677456,0.079916835,0.04507333,0.051850803,0.0068983436,-0.016310321,-0.026867833,0.044776775,0.0349464,0.08055085,0.022106638,-0.055502757,-0.03428399,0.05178887,0.013081721,0.0129298,-0.0031278566,-0.021336466,-0.06243512,0.09530947,0.0330554,-0.0006578708,-0.030082364,0.021180741,-0.047783434,-0.021518733,0.06492339,0.0023988164,-0.081713095,-0.029851474,0.0030383645,0.005961989,0.010959137,-0.011367861,-0.012766182,-0.06615919,0.018830422,-0.026043214,-0.017062845,-0.03944281,-0.019699648,-0.02940768,-0.023258017,-0.019670215,0.062609,0.06575933,0.01325001,0.04747316,-0.016266478,0.113097675,-0.06057502,0.02526323,-0.07107566,-0.025740916,0.012478688,0.06885636,0.049794856]	2026-05-22 12:21:03.70362+00	2026-05-22 12:21:03.70362+00
113dc283-57e3-4ce8-af2f-3375e79b885e	00000000-0000-0000-0000-000000000001	faq_agent	country_rule	org	\N	faq_agents	{"answer": "Core agents include: Documentation Agent, Compliance Agent, Logistics Agent, Finance Agent, Communication Agent, and Supervisor Agent.", "question": "What AI agents exist in TradeOS?"}	95.00	seed	1	2026-05-22 12:21:03.708489+00	\N	[-0.075103275,-0.05763268,-0.045224693,-0.02156743,0.03252004,-0.012762754,0.060312852,0.011598342,-0.0054319594,0.07611913,0.002192199,-0.050426926,-0.010367894,0.047826827,0.012554154,0.061668694,0.051697984,0.025593996,-0.05200215,-0.07440534,0.023616038,-6.803675e-05,-0.077607356,-0.034937542,-0.052584514,0.017903168,0.031156769,-0.08822526,-0.03189338,-0.040398017,-0.06417776,0.015353516,0.075281754,0.06499477,-0.008109132,0.08811715,-0.041345898,-0.022699626,0.0485224,-0.03159385,-0.0014936859,-0.0023315328,0.0032971161,-0.068413585,0.054069437,-0.016337182,-0.04208954,0.030245958,0.05939506,0.0058302665,-0.1408817,-0.044249464,0.0071734046,0.088284105,-0.024411434,-0.028253203,-0.04368325,-0.01223954,0.02559907,-0.06640653,0.028790003,-0.053739294,0.046272524,0.07015094,0.029964795,0.05919711,-0.05647771,0.031365562,-0.05244409,-0.08041098,0.060838614,-0.036005583,-0.037208475,0.0009967003,0.019991169,0.024010284,0.033333443,-0.044421025,0.071814135,-0.06328998,-0.025293132,-0.010446601,-0.03040789,0.07531218,-0.03964583,0.025722137,-0.017389886,-0.0013066593,0.09317946,0.027690208,0.0034104406,-0.06567208,0.009145925,-0.02661524,0.07695497,0.05262713,0.03569483,0.010990102,-0.040514275,0.052876398,-0.02854786,-0.009523345,-0.027110279,-0.0068679717,-0.05226221,0.036839135,0.034944173,-0.07744257,0.047897525,0.015386264,-0.10551572,-0.005897163,0.0120853335,-0.027879871,0.050070234,-0.022926245,0.006688259,0.07901789,-0.021365954,0.01862885,0.06028338,-0.026007382,-0.006754504,0.027744919,0.08510118,0.07271109,-0.030821893,-3.0762035e-33,-0.038534433,0.023818156,0.058948413,0.0066196118,0.04327819,-0.056549005,-0.0072206776,-0.015938668,-0.019339122,-0.0014471067,-0.15703547,0.08603149,-0.057215396,0.07486495,0.023267122,-0.031505227,-0.010744329,0.005957492,0.01933809,0.023022301,0.037346046,0.024884347,-0.018397273,-0.017995339,-0.011050674,0.09854575,-0.001873901,-0.082263395,0.09183212,0.017966708,-0.040786825,0.099343084,-0.08233429,0.07701029,-0.041572344,0.073385656,-0.113848165,-0.047488376,-0.0024851516,0.04309859,-0.0054608188,0.057216853,-0.0035150493,-0.032677375,-0.004453562,-0.101714864,-0.013464182,-0.011388628,0.04838448,0.010374566,-0.058980826,0.048242044,0.016173854,-0.09569741,0.10697351,-0.014666687,-0.0017777084,0.047436964,-0.008469403,0.056065783,-0.024884637,0.055847537,-0.0060859737,0.06786118,0.0034737654,0.08468197,-0.04021926,0.0054583685,0.051121503,0.044657502,0.005639491,0.03541763,-0.00045174715,0.06825616,-0.061596267,-0.024119046,0.015550422,-0.10185918,-0.042842567,-0.034770604,-0.091116324,-0.033464685,-0.025199078,0.12319878,0.017972896,-0.043936327,-0.03365786,-0.023295054,0.04258616,0.021049252,-0.094818436,-0.0049995063,-0.070568405,0.015964707,-0.059841167,7.332126e-34,-0.05055344,-0.072283156,-0.07129635,-0.004282708,-0.04675789,-0.03557025,-0.037393812,-0.015269636,0.08425201,0.04293396,-0.004997266,-0.012167795,0.05669007,-0.018052131,0.03524249,-0.054509193,0.04636625,-0.034143675,0.026335338,-0.06234271,0.035898052,0.062369738,-0.098734014,-0.028086089,0.0927499,0.018311726,-0.063188724,0.072100565,-0.056151237,0.036963075,0.047212146,-0.0044202562,-0.016016522,0.04055969,0.030622486,0.09777176,0.009221728,0.030489512,-0.014061748,0.03227945,0.048704863,-0.06291565,0.0029419372,0.061170474,-0.044994503,0.011438047,-0.06987598,0.08933647,-0.020471731,-0.04570441,0.02315873,0.048063233,-0.06727961,-0.088956065,-0.053600673,0.05025401,0.013758475,0.031794526,-0.0044943574,0.002197169,-0.005559192,-0.04996771,0.009373708,0.028473359,-0.024302844,0.026791435,-0.024098989,0.04601268,-0.026651116,-0.055051398,0.16137308,-0.0078088613,-0.071193986,0.040920977,0.0045203795,-0.02636449,-0.09780898,-0.01633812,0.019842427,-0.04755727,-0.043503888,-0.027495911,0.06891385,0.02283443,0.045874696,0.094443746,-0.04169119,-0.012335468,-0.0030157391,0.034485247,-0.025039265,-0.013009554,-0.0076970165,0.003817298,-0.14017932,-1.4074291e-08,0.012936639,0.005371537,0.13874057,3.3879904e-05,-0.043800313,-0.026651869,-0.00413167,0.021402476,-0.039014522,0.026197566,0.06115958,0.008003433,0.02677249,-0.01905892,0.12690118,0.040422633,0.02025064,0.02799632,-0.03863115,-0.019100051,0.09655595,0.020895645,-0.042477094,-0.051023383,0.008635828,-0.048344962,0.020527048,-0.008367434,-0.06659451,0.13579313,-0.016198963,0.0170482,0.017772196,-0.06576863,0.073986806,0.06846219,-0.041990947,-0.086942844,-0.028846493,-0.06805386,-0.052219816,0.052190267,-0.041209243,-0.021050815,0.11315299,0.0071361936,-0.023225589,-0.106224515,0.09818043,-0.055916492,-0.041709114,0.027790466,-0.00330846,0.044350155,0.07162354,-0.029871298,0.04597693,-0.07105205,0.0045237266,0.016710984,0.0020165036,0.0435797,0.03141946,-0.039330095]	2026-05-22 12:21:03.708489+00	2026-05-22 12:21:03.708489+00
f6e94c21-3961-4b7c-aec0-7712a4b1d0c3	00000000-0000-0000-0000-000000000001	faq_agent	country_rule	org	\N	faq_autonomous	{"answer": "No. TradeOS uses AI automation with human approval checkpoints, audit trails, and escalation workflows. Critical decisions still require human review.", "question": "Is TradeOS fully autonomous?"}	95.00	seed	1	2026-05-22 12:21:03.713104+00	\N	[-0.013061656,-0.031077884,-0.032636173,-0.008274654,0.03131454,-0.09236182,0.030273013,0.024638716,-0.09834575,0.078897506,0.040706865,0.06582543,-0.03617543,0.028806284,0.0036724205,0.022854947,0.078746445,-0.0050152796,-0.05757347,-0.00090322434,-0.030694252,-0.009165083,-0.0628213,0.008907135,-0.046414867,-0.019219875,0.036427855,-0.026380753,-0.06165171,-0.04531604,-0.09905835,-0.0016637368,0.077613994,0.06239295,-0.021961382,0.017288204,0.018035647,-0.058576506,0.02154174,-0.07556957,0.028905056,-0.06396423,0.023698723,-0.033581663,0.031376645,0.04982705,-0.010843925,0.015615106,0.022193747,-0.08999091,-0.06400214,-0.028704137,0.0028851908,0.017688699,-0.04421939,0.036020454,-0.043596458,-0.015956681,0.075628534,-0.05826234,0.043591116,-0.019424187,0.014906325,0.13065621,0.06600927,0.04451952,-0.005929102,-0.03429781,-0.034167312,-0.021094466,0.120168015,-0.057656962,0.026543058,-0.0009677471,0.031002177,0.021078957,0.029170703,0.010102183,0.017454566,0.008180464,-0.0024936057,0.0076042544,-0.010288729,0.051510558,-0.062460415,-0.013980528,-0.039392352,0.015027454,0.07705613,0.01746545,-0.00073732313,-0.048333876,0.02042505,-0.081263654,0.03233969,-0.0023619893,0.10501054,-0.0030471084,-0.032172155,-0.004015897,-0.007957236,0.01417633,-0.063431025,-0.044258513,-0.018795505,0.06584919,-0.01623694,-0.05886093,0.051158395,0.052594107,-0.1073444,-0.016388714,0.05769636,0.003600455,-0.07851971,-0.00454035,-0.07563017,0.0052266615,-0.01566922,0.026720505,0.014672256,-0.10310981,0.03054824,-0.058780286,0.054873306,0.025215048,0.06646756,-4.0883076e-33,-0.088495225,0.0074807913,0.042463936,-0.03441487,-0.014348334,-0.035691038,-0.049844302,-0.04972745,-0.06055577,0.0331337,-0.13680106,0.055725865,-0.021442987,0.09033178,0.06533223,-0.021215279,0.013895291,-0.033269845,0.03306236,0.046256743,0.0823391,-0.019053249,-0.044231594,-0.12906575,0.042302717,0.07232513,-0.003942827,-0.049468882,0.036137957,0.04292106,-0.09517658,0.07936317,-0.10411814,0.11887899,-0.014335796,0.06587582,-0.10762872,-0.04275135,-0.037725236,0.022589367,0.04175994,0.011105887,-0.103292614,-0.01708781,0.021939838,-0.06285608,-0.025660295,0.012289831,-0.031480435,0.049973376,-0.038729947,0.04668445,-0.049831707,-0.098722726,0.1033121,-0.026605956,-0.0145600755,0.027541026,0.007406535,0.07199081,-0.051983546,0.018497614,-0.04172532,0.033765975,0.021081463,0.09599326,-0.031918146,-0.025310928,0.030640556,0.022241756,0.05716665,-0.012909729,-0.04535995,0.062025014,-0.012476654,-0.01578301,0.10218858,-0.014523363,-0.01657081,0.01950644,-0.07419809,0.04900842,0.0166583,0.1372124,0.03599693,-0.012706565,-0.028292779,-0.010751215,0.013440718,0.05204494,0.011360029,-0.022462327,-0.103398,0.0029319937,-0.011649282,1.6909332e-33,0.00018765149,-0.057386216,-0.0026122888,0.024127591,-0.11080101,0.004264666,-0.0072418354,-0.0032804823,0.092742786,0.058453523,-0.02601052,-0.00084631506,0.10504239,-0.005087388,0.031501077,-0.01665556,0.017932767,-0.029409626,-0.020098036,-0.021849662,-0.01717389,0.017020704,-0.058442064,-0.0029665965,0.09553544,0.0054719565,-0.10968982,0.07667769,-0.0858573,0.026123185,0.073139876,-0.006713242,-0.039566014,0.015479156,0.022023357,0.07136929,-0.05160935,0.09701801,0.011620083,0.059296202,-0.0011326468,-0.011926442,-0.039938755,0.09424485,-0.017100437,0.005691577,-0.021870052,0.051136505,0.0030762353,0.043685474,0.017583728,0.14079371,-0.006321412,-0.01088385,0.052767273,0.05063184,-0.0072355787,0.032044124,-0.0520578,-0.032046653,0.022224197,-0.0016178219,0.012729314,0.0338367,0.014600639,0.007854657,-0.034677785,-0.031085236,-0.02961771,-0.026191803,0.12610829,-0.028205585,-0.07646179,-0.009940928,0.06293044,-0.03363749,-0.0049240394,-0.010695388,-0.015691407,-0.051477518,0.02047851,0.011436326,0.114719935,0.012392276,-0.0020342015,0.03223181,-0.078614146,-0.071636915,0.038638607,0.06526017,0.024373326,-0.047778733,-0.016668806,0.012363928,-0.09599237,-1.3725769e-08,0.007339211,0.014153154,0.07148105,0.043094046,-0.070174284,0.050368536,0.07266955,-0.016629709,-0.06594497,0.014388524,0.03616144,0.031059945,-0.024654154,0.038149107,0.039943445,0.09589334,0.06886272,0.00955144,-0.049503844,0.07798546,0.050113957,0.0016709355,-0.10629669,-0.050605074,0.0048346315,-0.015181789,0.032492302,-0.041954543,-0.033993315,0.07345362,-0.01977483,-0.019178752,-0.06927006,0.028971551,0.011926727,0.020278102,-0.041928772,-0.008994813,-0.022714667,-0.12536809,-0.02250114,0.08574515,-0.07636408,0.012160517,-0.01061106,-0.0062524667,-0.037358176,-0.09104001,0.0441741,-0.06532827,-0.0062668184,0.0064491415,0.029220978,-0.016983995,0.10833807,0.022562273,0.08315587,-0.08529572,-0.02617542,0.005070943,-0.0384949,0.0022593024,0.05435692,-0.06913315]	2026-05-22 12:21:03.713104+00	2026-05-22 12:21:03.713104+00
1f605b22-b870-445a-86c4-d292eb1b9f4f	00000000-0000-0000-0000-000000000001	faq_agent	country_rule	org	\N	faq_multilingual	{"answer": "Yes. Supported languages include English, Arabic, Hindi, and Malayalam.", "question": "Does TradeOS support multilingual workflows?"}	95.00	seed	1	2026-05-22 12:21:03.717041+00	\N	[-0.052788083,-0.048156884,-0.031125093,-0.058487125,-0.035212193,-0.047621287,0.020410651,-0.035644323,0.027879456,-0.031692293,-0.04334379,-0.015906423,-0.044269796,0.09133906,0.10960774,0.005482212,-0.029489446,0.091386504,-0.026216842,-0.08337006,0.048341315,-0.015242255,-0.019837955,0.019050982,0.0019335222,-0.07982933,-0.021040251,-0.042457383,-0.01155189,-0.02292775,-0.04172029,0.120747894,0.018137833,0.099107206,-0.0010411477,0.068507805,0.0031143501,-0.05860652,-0.028227253,-0.011391993,-0.056856778,0.025719853,0.004406155,-0.05528486,0.04213773,-0.00014372148,-0.04895605,0.056230806,-0.023083674,-0.01943368,-0.10441337,-0.06651706,0.04543117,0.08062168,0.020661557,0.0013440913,0.03791197,0.011957136,-0.0026347185,-0.04077523,-0.062595464,-0.047896717,0.026910646,0.105490215,0.016036997,0.049576655,-0.0031459425,0.024373747,-0.10293948,-0.055186283,-0.009581812,-0.03319855,0.014752456,0.040860012,-0.00372402,0.059485227,0.034179285,-0.05284337,-0.027806541,-0.065598406,0.014545538,0.058129907,0.0043904623,-0.0147071,0.034150064,0.010118526,-0.036252923,0.023760686,0.0752259,0.04187842,-0.02470427,-0.08174315,0.03819198,-0.030789305,-0.0015599541,-0.054707084,0.08326317,0.088084735,-0.048019316,-0.021175811,0.01738007,-0.01654204,0.05225739,-0.05855386,-0.075128496,0.024482537,0.03831121,-0.024424741,0.044427667,-0.036468383,-0.06799541,0.040506747,0.0024652549,-0.027269062,-0.042787477,0.015118184,0.018183226,-0.039686803,0.016372235,0.075270034,-0.05529701,-0.0025496269,-0.024660502,-0.09937419,-0.0354945,-0.023649389,0.048858795,-1.255473e-33,0.031277597,0.0374663,-0.0004070934,-0.0071407603,0.08784503,-0.047674164,-0.01676306,-0.062432192,-0.048832122,-0.09282906,-0.074339956,0.15547752,-0.04873111,0.07345149,-0.03278444,-0.025035271,0.03648017,0.08368017,0.08606639,0.10259211,0.09256273,-0.052206118,-0.027207574,-0.03601126,-0.029286839,0.06474237,0.031272277,-0.04729699,0.08510881,0.019547103,-0.097627014,-0.016684955,-0.021631869,0.089042015,-0.036953982,0.015751524,-0.054548882,-0.03188557,0.06878167,-0.005199109,0.013037292,0.032892846,-0.07184088,0.027197823,-0.020978114,-0.027649656,-0.05009967,0.0079565495,0.06350557,-0.010471281,-0.014317081,-0.024613291,0.021638276,-0.052129693,0.14590529,0.017358778,0.011293968,-0.007312029,0.08125628,0.027461668,-0.0791618,0.019535946,-0.017948931,0.056054402,0.061466057,0.016834833,-0.040651172,-0.022098398,0.049420793,-0.043403912,-0.047076847,0.041092623,0.011514936,0.13587646,-0.039185513,0.04795683,0.042020936,-0.05223276,0.039341364,0.009432292,-0.06671261,-0.012231548,0.045420233,0.102590345,0.060259175,0.065191954,-0.000758053,0.022380212,0.017077805,0.029957743,-0.0014271577,-0.029332472,-0.0023928722,-0.03482201,0.039210092,-7.5853016e-34,-0.07035048,-0.067146085,-0.055941634,0.044400692,-0.074677795,-0.0292585,0.049338933,0.020654684,0.09764841,0.0016192753,0.047554936,-0.049149577,0.052106477,0.0044646347,0.018607358,-0.05145548,0.045418084,0.07670619,0.022736186,0.039078802,-0.03822563,-0.0001759382,-0.11004074,0.024037395,0.05612537,-0.0069538015,-0.10899489,-0.025443995,-0.062789686,0.01241699,0.07991058,-0.03889178,-0.05446797,0.06938192,0.04519313,-0.03119977,-0.068703376,0.0539304,0.054647233,0.062789805,0.03391046,-0.031299062,-0.02795109,0.052611697,-0.03622439,0.05408607,-0.108443305,0.0062600067,-0.031798404,-0.06424371,0.049801677,0.033007104,-0.048553962,-0.11575374,0.04065975,-0.013517709,0.02724734,-0.06901685,-0.1203766,-0.05239759,-0.058206927,0.00939202,0.08772332,-0.06381267,0.0810306,0.011002803,-0.01817384,-0.057624515,-0.020115515,-0.041373666,0.12612337,-0.035756078,-0.079070985,0.014979934,0.03353831,-0.056109168,-0.028078822,-0.076219894,0.03266178,0.013631557,-0.05169481,0.023704698,0.095117494,-0.02913714,0.050743394,0.038274225,-0.083949685,0.023508836,0.050773628,-0.03389892,-0.026495466,0.042174015,-0.03107913,-0.029189656,-0.009709835,-1.7268343e-08,-0.03724723,-0.0032309105,-0.0009585629,0.017334426,-0.11154894,-0.031856775,0.010232027,0.02746475,0.022866143,0.053025592,-0.022774316,0.0009471635,0.002424648,-0.0667089,0.025366167,0.026011402,0.12828425,0.10679044,-0.005916035,-0.00670169,0.09782826,0.022867234,0.008675965,-0.016384011,-0.02387163,-0.008832643,0.030602364,-0.00926017,-0.005019713,-0.1095483,0.012412242,-0.016865088,-0.08765458,0.026732523,0.020088121,-0.067647964,-0.048860993,0.031909995,0.022011407,0.0023380904,0.03549495,0.020046258,-0.048042536,0.020547055,0.010649362,-0.02499889,-0.07929742,-0.0692786,0.009204908,-0.03711331,-0.009820769,0.028189607,0.052714277,0.055395644,0.05713231,0.014399195,0.019172486,-0.044974193,0.056872148,0.009361399,-0.024991354,0.0061626136,0.05165867,-0.002738045]	2026-05-22 12:21:03.717041+00	2026-05-22 12:21:03.717041+00
d61dcc6a-e6e6-4e2a-80b4-c2a16227a971	00000000-0000-0000-0000-000000000001	faq_agent	country_rule	org	\N	faq_pricing	{"answer": "Pricing depends on product grade, quantity, destination country, Incoterms, seasonality, and freight cost. TradeOS AI generates indicative pricing ranges based on historical quotations and current market conditions.", "question": "What are your typical price ranges?"}	95.00	seed	1	2026-05-22 12:21:03.720863+00	\N	[0.06509857,0.0006284166,-0.028687082,0.019825308,-0.0567447,0.020843616,-0.02289526,0.061194837,0.007534751,0.017845895,-0.021854855,-0.04682909,-0.0029904223,-0.033356715,0.018222235,-0.014560189,0.077915326,-0.04106004,0.015529716,0.023568118,-0.09625859,0.020657351,0.020666145,-0.0031383773,0.01816669,-0.088231936,0.012138478,-0.0031496529,-0.017126717,0.014847159,-0.030852895,-0.033196718,0.028805055,-0.0428787,0.001950339,-0.055962734,0.0022846407,-0.021560883,-0.041464217,-0.0002653226,0.019127492,-0.04526297,-0.059793305,-0.027943928,0.038105495,0.033571422,0.02063066,0.05135511,0.020306092,0.014515354,-0.0017047533,0.040201016,-0.044856343,0.04817137,-0.03825332,-0.031473838,-0.08165363,0.020715477,0.071754865,-0.009911969,-0.018711878,-0.022866853,-0.07444022,0.03175641,0.0063049537,-0.022534603,-0.055883482,-0.041965883,0.027980926,0.010528452,-0.09921816,0.0222277,-0.015795397,0.044867367,0.019149115,-0.0056795375,0.08904995,-0.068195745,-0.07695622,-0.040293094,-0.05655343,-0.044920254,-0.02451731,-0.03550189,0.08316836,-0.030633632,0.046645734,0.13048153,0.035788413,0.041056708,0.042453118,-0.007980494,-0.009966873,-0.010246744,-0.056513503,0.062644474,0.06740108,-0.10521152,0.058521625,0.030636728,0.07102919,-0.013642058,0.07912616,-0.05992014,-0.010548391,0.0148251625,0.0037185329,-0.008657617,-0.003149639,0.0047559296,-0.070431076,-0.03740148,-0.10350377,-0.09412451,0.015365343,-0.10061368,-0.032163497,-0.029447883,0.08216063,0.020657966,0.00031079946,-0.04596989,0.043141317,-0.010529744,-0.1224417,0.0036189451,-0.082876146,-4.988805e-33,0.026237654,0.02361444,-0.061784543,0.06980821,-0.038027562,0.027994564,0.0051158047,-0.022368453,0.014572651,0.17567018,0.039338943,0.06980102,-0.03596116,0.04713149,0.083211064,0.02278019,0.029706834,-0.0367022,0.0013490337,-0.04131809,-0.10148246,0.035346493,-0.030705119,0.07005348,-0.004518139,0.030345228,-0.0047090547,-0.02577526,0.0778065,-0.008421098,-0.03878719,-0.013282319,0.0694568,-0.07660794,0.011608363,0.016073065,-0.0861893,-0.06199484,0.011418542,0.017041441,-0.04153146,0.09556175,0.028423218,0.009342501,0.10039897,0.0028394558,0.034935337,0.057975374,-0.14366512,-0.0012136026,-0.11442663,0.07432716,-0.064158045,0.043159794,-0.034513418,-0.010615916,-0.0005980412,-0.04282061,0.006155468,0.051301576,0.0536344,0.047332637,-0.01534217,-0.025458358,-0.08097448,0.10118229,-0.0623132,0.00048062988,-0.051613934,0.08609229,0.010003973,-0.002474517,0.06597833,-0.07492137,-0.022204867,0.0056957183,0.015618959,-0.0044847587,0.016922649,-0.0026811326,-0.017785797,0.093920924,0.038253777,0.06800557,-0.054521132,-0.006696503,-0.10029462,-0.014943368,-0.05812414,-0.041563842,-0.008816031,0.054804336,-0.030860871,-0.020426586,-0.01382755,2.1755598e-33,0.013420545,0.05435135,0.032832958,0.063741155,0.0481749,0.014249532,0.030316966,0.08095815,0.017713677,0.053721365,-0.10257265,0.0037662138,0.08366985,0.05375676,-0.07685962,0.004409281,0.057950094,-0.005381529,0.1199883,-0.11233756,0.012135074,0.11713044,-0.006666047,0.06634139,0.0054198587,0.00697729,-0.07673752,-0.0031003866,-0.049615648,-0.0707496,-0.04997066,-0.0332184,0.07140764,0.05513563,-0.03667738,-0.013336907,0.040523265,0.097522706,0.025987763,0.024346545,0.04932915,-0.030890467,0.13074824,0.06718997,0.02359551,0.0044459356,-0.023802048,-0.088262305,0.020492183,-0.027760915,-0.06407097,-0.009962769,-0.0040189717,-0.031554334,-0.05331378,-0.03281275,-0.004523231,0.03801302,-0.020876879,-0.045922946,0.020069152,0.0659165,0.00051110535,0.10074604,0.0019949663,0.0037145175,0.0423156,-0.023116035,-0.06401743,-0.020852951,-0.02629121,-0.09991373,0.09760318,-0.107035995,-0.078374565,-0.074927725,0.06794532,-0.041116763,0.098057546,0.05968115,-0.018724984,0.042755287,0.066281214,-0.0023644818,-0.007975355,-0.07105024,-0.038656678,0.020396633,0.02254091,0.051923808,0.035390507,0.028727558,-0.0066759638,-0.057072446,-0.01938061,-1.7526274e-08,-0.00025313,0.07691884,0.00065938814,0.015824633,0.037509397,-0.023326764,0.02353349,-0.025819974,-0.016991027,0.011049246,0.059084717,-0.08591003,-0.026219139,-0.032413136,0.03374654,-0.00024095806,-0.018176857,0.04697237,0.023666421,-0.029153712,0.020998886,0.06476697,0.01797584,-0.032948013,0.0010025186,0.051426403,0.0011798696,0.06554201,-0.046097536,0.053386986,-0.031986527,0.0032706177,0.0179728,-0.039692868,-0.071808286,-0.018370014,-0.0658066,0.019189982,-0.031094655,-0.029158046,0.041230623,-0.10186403,-0.072807655,-0.018572386,0.021862347,0.034654785,-0.10028548,0.04911747,0.005442,0.07076406,0.018130671,0.027973618,0.026959663,-0.03497239,0.025428327,0.012220252,0.03702571,-0.0055917627,-0.022944184,-0.03270155,0.0834701,-0.12628524,-0.115169644,0.028412364]	2026-05-22 12:21:03.720863+00	2026-05-22 12:21:03.720863+00
65c91bda-299c-4fc6-9123-6fba4dfcd8cf	00000000-0000-0000-0000-000000000001	faq_agent	country_rule	org	\N	faq_erp	{"answer": "Yes. Planned integrations include Tally, Zoho Books, Odoo, and SAP Business One.", "question": "Will TradeOS support ERP integrations?"}	95.00	seed	1	2026-05-22 12:21:03.725009+00	\N	[-0.055584442,-0.022946885,-0.023926862,-0.038330495,0.022399442,-0.043122932,0.030909026,0.05690327,-0.058299415,0.010864778,-0.019527467,0.05634507,-0.021422407,0.06208939,0.11455648,0.026720826,0.06988529,0.007917791,-0.029588146,0.004660652,-0.07606235,-0.037152678,-0.1014251,-0.011524786,0.007894223,-0.08161682,0.083012365,-0.029218744,-0.09488163,-0.028296065,-0.077111505,-0.046557184,0.03367577,0.102033556,-0.009531515,-0.017558433,0.09290868,-0.058336016,-0.050597426,-0.09518523,0.023507623,0.0008145172,-0.06983861,-0.025082994,0.030122617,-0.005664599,-0.043295156,0.019338658,0.0058241864,-0.044148527,-0.004287489,0.00040688112,0.057298567,0.058039505,-0.07489952,0.05175563,-0.010186321,-0.024529904,-0.007191699,-0.01450261,0.021136912,-0.07799572,0.037630495,0.07191636,0.018855246,0.07208178,0.017481873,-0.012025468,-0.082968034,-0.070286214,-0.059670724,-0.0973329,-0.0933926,-0.005973272,0.044135246,0.04274611,0.022061797,0.034911145,0.04321245,-0.04737087,0.01207904,0.12212347,-0.04446132,-0.012809433,-0.07035234,0.021524524,-0.0034295272,0.0014781053,-0.014226508,-0.015658569,0.028956726,-0.11759973,-0.03143224,-0.05286292,0.03487879,-0.017189533,0.026936768,-0.005063283,0.009103791,-0.031448748,0.00523486,0.04932742,-0.015378281,-0.092777394,-0.0638484,0.00865964,-0.010009655,-0.024831615,0.06538128,0.031199956,-0.06727737,-0.012606554,0.052674036,-0.046426333,-0.0077441703,0.009876693,-0.081220165,-0.03239184,0.020774977,0.02984603,0.057108104,0.000294506,-0.008176233,-0.042327613,0.043833774,-0.00929674,-0.002111695,-2.7389364e-33,-0.08173301,0.023806542,-0.028684143,-0.02966149,0.060891412,-0.008104095,-0.022599192,-0.10375188,-0.052441377,-0.05370354,-0.1861756,0.13309895,0.028987566,0.06522333,0.05197774,0.056634363,-0.018265108,0.11270497,0.1534296,0.05795322,0.008394459,-0.088657975,-0.005744024,-0.05629854,0.035103478,0.09409983,-0.0477519,0.009334587,0.13283263,-0.00314796,-0.026633454,0.024350084,-0.038637497,0.07885986,-0.012115331,0.045591082,-0.06315011,-0.05358067,0.023175722,-0.07670907,-0.043547805,0.10344163,-0.090514556,0.07840375,-0.004560007,-0.06846189,0.04125583,-0.0012581893,0.11550507,-0.02893499,-0.050259754,-0.033039715,0.031173417,-0.0713305,0.086854614,-0.009742592,-0.008213501,-0.034082647,0.047882456,0.005557475,-0.02361658,-0.006331165,-0.03689939,-0.014058797,0.016950035,0.068777956,0.04254105,-0.0052804956,-0.0001735298,-0.006840088,0.021457352,0.004282704,0.0086811185,0.057652917,-0.07021512,-0.0076387348,0.0043377243,0.056491423,0.025539624,0.07482023,-0.07654798,-0.051481918,0.030705072,0.12586121,0.09057576,0.027574942,0.024721308,0.0650845,-0.0026131188,0.031602975,-0.02598781,-0.023754396,-0.04148918,0.059064325,0.022482509,2.40952e-34,0.008786728,-0.055148643,-0.03444337,0.0013792977,-0.024183847,-0.0019991382,0.02149183,-0.031981457,0.0426118,0.037166297,0.056711335,-0.044195514,0.033599865,-0.030626373,0.022984348,-0.057927925,0.023915611,0.032200545,0.005670219,-0.0084131155,-0.004311835,4.394523e-05,-0.036845118,0.025842154,0.07970464,-0.012221847,-0.13371035,-0.029328577,-0.08577929,-0.0074780546,0.0644896,0.0045198626,-0.030901078,0.0453284,0.02213507,-0.03580157,-0.03516721,0.058765613,0.023954468,-0.06631476,0.06407182,0.019494703,-0.032486647,0.03789208,0.011782782,0.034288168,-0.09215088,0.031051703,-0.0069873515,-0.047559205,0.0037859457,0.12654719,-0.00023929215,-0.0711562,-0.016404886,0.050141394,0.039044425,0.0028751178,-0.12847264,0.00401481,-0.037280142,0.026851358,0.080057405,-0.027893191,0.079625376,0.051872663,0.021952257,-0.0701022,-0.0526754,-0.02190753,0.12483035,-0.031534445,-0.034728777,0.0048628347,-0.0008259071,-0.028304627,-0.018457346,-0.0063482304,-0.002240341,0.01278187,-0.044707898,-0.0077073826,0.07833263,-0.0039544343,0.048542444,0.002049128,-0.05666548,-0.038722202,0.01644581,-0.025142947,-0.06285442,-0.05460356,-0.02434936,0.027349336,-0.047676124,-1.569825e-08,0.010116748,0.02389476,0.011556173,0.016871506,-0.1061294,-0.019051403,-0.024630278,0.030779291,-0.05342655,0.09823508,0.018751044,-0.025380727,-0.051436663,0.021031884,0.1000962,0.048312474,0.10486902,0.080115005,-0.031689655,-0.046105683,0.08734711,0.052183542,-0.0028205547,-0.04220262,0.09665532,0.029053634,0.000872208,-0.013499246,-0.018486282,-0.022350429,0.04076618,-0.04755015,-0.039422784,0.032607216,0.049063027,-0.054046005,-0.036857195,0.02128662,-0.026543928,-0.0369311,-0.048971757,0.03913246,0.008194492,-0.0020597836,0.022818513,-0.020429878,-0.045042016,-0.05399053,0.0316244,-0.02168281,0.016283464,0.032044556,0.04096654,0.024226591,0.05924471,-0.018974552,0.094025254,-0.045186516,0.016419202,0.038633406,-0.016154822,-0.030363573,0.040959895,0.014868231]	2026-05-22 12:21:03.725009+00	2026-05-22 12:21:03.725009+00
\.


--
-- Data for Name: approval_requests; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.approval_requests (id, org_id, workflow_id, workflow_step_id, order_id, document_id, requested_by, title, description, ai_confidence, risk_flags, suggested_action, diff_before, diff_after, status, assigned_to, reviewed_by, reviewed_at, review_note, expires_at, created_at) FROM stdin;
72f16bce-ff13-41f2-ac15-1f434677d601	00000000-0000-0000-0000-000000000001	861458b2-05a9-4e22-82ce-8e14614c655b	\N	a368e2e7-5d54-4a1d-b967-14e4a39caf1e	\N	hitl_supervisor_agent	PO Review Required — WA-861458B2	High-severity flags: ['Automated compliance checks failed/timed out. Manual verification of HS codes and regulations required.']	45.00	[{"source": "hs_validation", "message": "Automated compliance checks failed/timed out. Manual verification of HS codes and regulations required.", "severity": "high"}, {"source": "hitl_decision", "message": "Confidence score (45%) is below the auto-approval threshold (60%)", "severity": "medium"}]	require_human	\N	{"packing_list": {"_draft": true, "pl_number": "PL-861458B2", "_confidence": 60.0, "total_packages": 1, "total_volume_cbm": 0, "total_net_weight_kg": 0, "total_gross_weight_kg": 0}, "commercial_invoice": {"items": [{"qty": 25.0, "unit": "KG", "description": "Basmati Rice"}], "_draft": true, "currency": "USD", "importer": {"name": "shipment date"}, "incoterms": "CIF", "_confidence": 60.0, "declaration": "Draft — pending review.", "grand_total": 0.0, "bank_details": {"name": "State Bank of India", "swift": "SBININBB"}, "invoice_date": "2026-05-26", "payment_terms": "LC", "invoice_number": "DRAFT-861458B2", "port_of_discharge": "Jebel Ali Port"}}	approved	00000000-0000-0000-0000-000000000002	00000000-0000-0000-0000-000000000002	2026-05-26 14:38:51.015129+00	Actioned via Agent Hub MVP	2026-05-26 18:38:37.857764+00	2026-05-26 14:38:37.859399+00
fa000000-0000-0000-0000-000000000003	00000000-0000-0000-0000-000000000001	ef000000-0000-0000-0000-000000000001	\N	a1000000-0000-0000-0000-000000000001	d1000000-0000-0000-0000-000000000001	hitl_evaluation	Soft review — HS code auto-suggested (confidence 87%)	WhatsApp PO from Al Noor Foodstuff. AI confidence 87%. HS code 1006302000 was auto-suggested (buyer did not provide). All other fields complete. Soft review flagged for optional human check.	87.50	[{"message": "HS code AI-suggested, not buyer-provided", "severity": "low"}]	Verify HS code is correct for Basmati Rice export to UAE.	{"hs_code_source": "ai_suggested"}	{"hs_code_source": "human_verified"}	approved	00000000-0000-0000-0000-000000000002	\N	\N	\N	2026-05-21 08:41:50.068651+00	2026-05-21 04:41:50.068651+00
2cac43dc-1ebc-48ec-82d7-8e0e72dd3bf0	00000000-0000-0000-0000-000000000001	e9ef93f8-b72f-4bd9-8722-de8458107f96	\N	c644e07a-56ba-4a7b-963a-fc334c7384aa	\N	hitl_supervisor_agent	PO Review Required — WA-E9EF93F8	Confidence 40.0% below threshold (45.0%)	40.00	[{"source": "hs_validation", "message": "HS code mismatch", "severity": "medium"}, {"source": "hitl_decision", "message": "Confidence score (40%) is below the auto-approval threshold (60%)", "severity": "medium"}]	require_human	\N	{"packing_list": {"pl_date": "2024-09-16", "summary": {"total_packages": 10, "total_volume_cbm": 1.5, "total_net_weight_kg": 200.0, "total_gross_weight_kg": 220.0}, "packages": [{"hs_code": "10063000", "width_cm": 50, "height_cm": 30, "length_cm": 100, "pkg_number": 1, "volume_cbm": 0.15, "description": "Rice", "packing_type": "bag", "net_weight_kg": 20.0, "gross_weight_kg": 22.0, "marks_and_numbers": "RICE-001", "number_of_packages": 10, "quantity_per_package": 1000}], "pl_number": "PL001", "_confidence": 45.0, "special_flags": {"fragile": false, "dg_cargo": false, "ispm15_required": false, "refrigeration_required": false}, "_missing_fields": [{"field": "packing_instructions", "blocking": true, "question": "Please provide detailed packing instructions for the shipment."}, {"field": "hs_code", "blocking": true, "question": "Please confirm the correct HS code for the product 'Rice'."}], "invoice_reference": "INV001"}, "commercial_invoice": {"gstin": "27AAAAA1234A1Z5", "items": [{"unit": "Kg", "sl_no": 1, "total": 1000.0, "hs_code": "10063000", "quantity": 1000.0, "unit_price": 1.0, "description": "Rice", "net_weight_kg": 1000.0, "gross_weight_kg": 1000.0, "country_of_origin": "India"}], "freight": 100.0, "currency": "USD", "exporter": {"pan": "AAAAA1234A", "city": "Mumbai", "name": "ABC Exports", "gstin": "27AAAAA1234A1Z5", "ad_code": "AD123456", "country": "India", "iec_code": "IEC123456", "address_line1": "123, Main Street", "address_line2": "Mumbai"}, "importer": {"name": "Buyer Name", "address": "Buyer Address", "country": "United Arab Emirates", "vat_trn": ""}, "subtotal": 1000.0, "incoterms": "CIF", "insurance": 50.0, "_confidence": 50.0, "declaration": "We declare that this invoice shows the actual price of goods described.", "grand_total": 1150.0, "igst_amount": 0.0, "bank_details": {"iban": null, "ifsc": "SBIN0001234", "branch": "Mumbai", "bank_name": "State Bank of India", "swift_code": "SBININBB", "account_number": "1234567890"}, "invoice_date": "2024-09-16", "lc_reference": null, "pre_carriage": "", "exchange_rate": 0.0, "other_charges": 0.0, "payment_terms": "LC", "vessel_flight": null, "inr_equivalent": 0.0, "invoice_number": "INV001", "_missing_fields": [{"field": "buyer_name", "blocking": true, "question": "Please provide the buyer's name."}, {"field": "buyer_address", "blocking": true, "question": "Please provide the buyer's address."}, {"field": "lc_details", "blocking": true, "question": "Please provide the LC details."}], "amount_in_words": "One Thousand One Hundred Fifty US Dollars", "lut_bond_number": "LUT123456", "port_of_loading": "JNPT", "port_of_discharge": "Jebel Ali Port", "_lc_compliance_flags": [], "authorized_signatory": "Authorized Signatory", "country_of_final_destination": "United Arab Emirates"}}	rejected	00000000-0000-0000-0000-000000000002	00000000-0000-0000-0000-000000000002	2026-05-27 13:56:23.275948+00	Actioned via Agent Hub MVP	2026-05-27 08:48:23.502537+00	2026-05-27 04:48:23.504567+00
46c081f2-80e6-40cc-8b68-dc742ba11c78	00000000-0000-0000-0000-000000000001	5cb9440f-5a3d-4c7e-8d3c-9c185aceed4e	\N	cc552ddb-ec65-4cd9-b972-cfa94da3ddd9	\N	hitl_supervisor_agent	PO Review Required — WA-5CB9440F	Moderate confidence (45.0%) — flagging for optional review	45.00	[{"source": "hitl_decision", "message": "Confidence score (45%) is below the auto-approval threshold (60%)", "severity": "medium"}]	soft_review	\N	{"packing_list": {"pl_date": "2023-10-27", "summary": {"total_packages": 5, "total_volume_cbm": 0.48, "total_net_weight_kg": 130.0, "total_gross_weight_kg": 150.0}, "packages": [{"hs_code": "84713010", "width_cm": 40, "height_cm": 40, "length_cm": 60, "pkg_number": 1, "volume_cbm": 0.096, "description": "Dell Latitude 7420 Laptops", "packing_type": "carton", "net_weight_kg": 26.0, "gross_weight_kg": 30.0, "marks_and_numbers": "DHIRAJ-GROUP-DXB-001-005", "number_of_packages": 5, "quantity_per_package": 20}], "pl_number": "PL-2023-DG-001", "_confidence": 45.0, "special_flags": {"fragile": true, "dg_cargo": false, "ispm15_required": false, "refrigeration_required": false}, "_missing_fields": [{"field": "Quantity", "blocking": true, "question": "The total quantity of laptops was not provided in the order data. I have assumed 100 units (20 per carton) for this calculation. Please confirm total unit count."}, {"field": "Incoterms", "blocking": false, "question": "Is the Incoterms CIF applicable for this shipment?"}], "invoice_reference": "LC-987654321"}, "commercial_invoice": {"gstin": "27AAAAA1234A1Z5", "items": [{"unit": "Units", "sl_no": 1, "total": 30000.0, "hs_code": "84713010", "quantity": 10.0, "unit_price": 3000.0, "description": "Dell Latitude 7420 Laptops", "net_weight_kg": 50.0, "gross_weight_kg": 60.0, "country_of_origin": "India"}], "freight": 0.0, "currency": "USD", "exporter": {"pan": "AAAAA1234A", "city": "Mumbai", "name": "ABC Exports", "gstin": "27AAAAA1234A1Z5", "ad_code": "AD123456", "country": "India", "iec_code": "IEC123456", "address_line1": "123 Export Street", "address_line2": "Mumbai"}, "importer": {"name": "Dhiraj Group", "address": "456 Business Avenue, Business Bay, Dubai, United Arab Emirates", "country": "United Arab Emirates", "vat_trn": "100293847563"}, "subtotal": 30000.0, "incoterms": "CIF", "insurance": 0.0, "_confidence": 60.0, "declaration": "We declare that this invoice shows the actual price of goods described.", "grand_total": 30000.0, "igst_amount": 0.0, "bank_details": {"iban": null, "ifsc": "SBIN0001234", "branch": "Mumbai Branch", "bank_name": "State Bank of India", "swift_code": "SBININBB123", "account_number": "1234567890"}, "invoice_date": "2024-09-16", "lc_reference": "LC-987654321", "pre_carriage": "Not Applicable", "exchange_rate": 0.0, "other_charges": 0.0, "payment_terms": "Letter of Credit (LC)", "vessel_flight": null, "inr_equivalent": 0.0, "invoice_number": "INV001", "_missing_fields": [{"field": "Incoterms", "blocking": false, "question": "Is the Incoterms CIF applicable for this shipment?"}], "amount_in_words": "Thirty Thousand US Dollars Only", "lut_bond_number": "LUT/Bond-123456", "port_of_loading": "JNPT, Mumbai", "port_of_discharge": "Jebel Ali Port, Dubai", "_lc_compliance_flags": ["LC Number", "Expiry Date", "Issuing Bank"], "authorized_signatory": "Authorized Signatory", "country_of_final_destination": "United Arab Emirates"}}	approved	00000000-0000-0000-0000-000000000002	00000000-0000-0000-0000-000000000002	2026-05-23 14:56:04.928318+00	Actioned via Agent Hub MVP	2026-05-23 18:49:04.36963+00	2026-05-23 14:49:04.371024+00
8e70eeea-0577-428b-8087-b6a4b970bfe4	00000000-0000-0000-0000-000000000001	ffbe6cc8-a990-4036-9078-3db7ee26072b	\N	e8d4f064-ccec-4bfb-b5e0-48d874894cd8	\N	hitl_supervisor_agent	PO Review Required — WA-FFBE6CC8	Moderate confidence (45.0%) — flagging for optional review	45.00	[{"source": "hitl_decision", "message": "Confidence score (45%) is below the auto-approval threshold (60%)", "severity": "medium"}]	soft_review	\N	{"packing_list": {"pl_date": "2024-09-16", "summary": {"total_packages": 1, "total_volume_cbm": 0.012, "total_net_weight_kg": 2.5, "total_gross_weight_kg": 3.0}, "packages": [{"hs_code": "8471.30", "width_cm": 30, "height_cm": 10, "length_cm": 40, "pkg_number": 1, "volume_cbm": 0.012, "description": "Dell Lattitude 7420", "packing_type": "carton", "net_weight_kg": 2.5, "gross_weight_kg": 3.0, "marks_and_numbers": "Dell Lattitude 7420", "number_of_packages": 1, "quantity_per_package": 1}], "pl_number": "PL-001", "_confidence": 45.0, "special_flags": {"fragile": false, "dg_cargo": false, "ispm15_required": false, "refrigeration_required": false}, "_missing_fields": [{"field": "country_of_origin", "blocking": false, "question": "Please provide the country of origin for the Dell Lattitude 7420"}, {"field": "packing_instructions", "blocking": false, "question": "Please provide detailed packing instructions for the Dell Lattitude 7420"}], "invoice_reference": "INV-001"}, "commercial_invoice": {"gstin": "29ABCDE1234F1Z5", "items": [{"unit": "Unit", "sl_no": 1, "total": 1000.0, "hs_code": "84713010", "quantity": 1.0, "unit_price": 1000.0, "description": "Dell Lattitude 7420", "net_weight_kg": 2.0, "gross_weight_kg": 3.0, "country_of_origin": "Please provide the country of origin"}], "freight": 100.0, "currency": "USD", "exporter": {"pan": "ABCDE1234F", "city": "New York", "name": "ABC Exports", "gstin": "29ABCDE1234F1Z5", "ad_code": "AD123456", "country": "USA", "iec_code": "IEC123456", "address_line1": "123 Main Street", "address_line2": "New York"}, "importer": {"name": "Dhiraj Group", "address": "Please provide the buyer address", "country": "Please provide the buyer country", "vat_trn": "Please provide the buyer VAT TRN"}, "subtotal": 1000.0, "incoterms": "CIF", "insurance": 50.0, "_confidence": 50.0, "declaration": "We declare that this invoice shows the actual price of goods described.", "grand_total": 1150.0, "igst_amount": 0.0, "bank_details": {"iban": null, "ifsc": "BOFA0001234", "branch": "New York Branch", "bank_name": "Bank of America", "swift_code": "BOFAUS3N", "account_number": "1234567890"}, "invoice_date": "2024-09-16", "lc_reference": null, "pre_carriage": "Not Applicable", "exchange_rate": 0.0, "other_charges": 0.0, "payment_terms": "LC", "vessel_flight": null, "inr_equivalent": 0.0, "invoice_number": "INV001", "_missing_fields": [{"field": "buyer_address", "blocking": false, "question": "Please provide the buyer address"}, {"field": "buyer_country", "blocking": false, "question": "Please provide the buyer country"}, {"field": "buyer_vat_trn", "blocking": false, "question": "Please provide the buyer VAT TRN"}, {"field": "port_of_loading", "blocking": false, "question": "Please provide the port of loading"}, {"field": "port_of_discharge", "blocking": false, "question": "Please provide the port of discharge"}, {"field": "country_of_final_destination", "blocking": false, "question": "Please provide the country of final destination"}, {"field": "country_of_origin", "blocking": false, "question": "Please provide the country of origin for the Dell Lattitude 7420"}], "amount_in_words": "One Thousand One Hundred Fifty US Dollars", "lut_bond_number": "LUT/Bond123456", "port_of_loading": "Please provide the port of loading", "port_of_discharge": "Please provide the port of discharge", "_lc_compliance_flags": ["LC number missing", "LC expiry date missing", "LC issuing bank missing"], "authorized_signatory": "John Doe", "country_of_final_destination": "Please provide the country of final destination"}}	approved	00000000-0000-0000-0000-000000000002	00000000-0000-0000-0000-000000000002	2026-05-23 14:56:31.07459+00	Actioned via Agent Hub MVP	2026-05-23 15:33:19.372553+00	2026-05-23 11:33:19.373873+00
bb3ef8ed-42ac-4c42-a501-b9ed63ff7b09	00000000-0000-0000-0000-000000000001	a90e7e81-2713-4731-aad7-edfe4c1ac77a	\N	d2f29e8a-f939-43ad-9156-ec46457405b8	\N	hitl_supervisor_agent	PO Review Required — WA-A90E7E81	Moderate confidence (45.0%) — flagging for optional review	45.00	[{"source": "hitl_decision", "message": "Confidence score (45%) is below the auto-approval threshold (60%)", "severity": "medium"}]	soft_review	\N	{"packing_list": {"pl_date": "2024-09-16", "summary": {"total_packages": 0, "total_volume_cbm": 0.0, "total_net_weight_kg": 0.0, "total_gross_weight_kg": 0.0}, "packages": [{"hs_code": "100630", "width_cm": 0, "height_cm": 0, "length_cm": 0, "pkg_number": 1, "volume_cbm": 0.0, "description": "basmati rice grade A", "packing_type": "bag", "net_weight_kg": 0.0, "gross_weight_kg": 0.0, "marks_and_numbers": "", "number_of_packages": 0, "quantity_per_package": 0}], "pl_number": "PL001", "_confidence": 45.0, "special_flags": {"fragile": false, "dg_cargo": false, "ispm15_required": false, "refrigeration_required": false}, "_missing_fields": [{"field": "country_of_origin", "blocking": false, "question": "Please provide the country of origin for the basmati rice"}, {"field": "packing_instructions", "blocking": false, "question": "Please provide the packing instructions for the basmati rice"}, {"field": "package_dimensions", "blocking": false, "question": "Please provide the package dimensions (length, width, height) for the basmati rice"}, {"field": "package_weights", "blocking": false, "question": "Please provide the package weights (net and gross) for the basmati rice"}, {"field": "quantity_per_package", "blocking": false, "question": "Please provide the quantity per package for the basmati rice"}, {"field": "number_of_packages", "blocking": false, "question": "Please provide the number of packages for the basmati rice"}], "invoice_reference": "INV001"}, "commercial_invoice": {"gstin": "07ABC1234E1Z5", "items": [{"unit": "Kg", "sl_no": 1, "total": 2000.0, "hs_code": "10063000", "quantity": 1000.0, "unit_price": 2.0, "description": "basmati rice grade A", "net_weight_kg": 1000.0, "gross_weight_kg": 1050.0, "country_of_origin": "India"}], "freight": 100.0, "currency": "USD", "exporter": {"pan": "ABC1234E", "city": "New Delhi", "name": "ABC Exporters", "gstin": "07ABC1234E1Z5", "ad_code": "AD123456", "country": "India", "iec_code": "IEC123456", "address_line1": "123, Main Street", "address_line2": "New Delhi"}, "importer": {"name": "Dhiraj Group", "address": "Buyer Address", "country": "Country of Buyer", "vat_trn": "VAT TRN of Buyer"}, "subtotal": 2000.0, "incoterms": "CIF", "insurance": 50.0, "_confidence": 50.0, "declaration": "We declare that this invoice shows the actual price of goods described.", "grand_total": 2150.0, "igst_amount": 0.0, "bank_details": {"iban": null, "ifsc": "IFSC Code", "branch": "Branch Name", "bank_name": "Bank Name", "swift_code": "SWIFT Code", "account_number": "Account Number"}, "invoice_date": "2024-09-16", "lc_reference": null, "pre_carriage": "Pre Carriage", "exchange_rate": 1.0, "other_charges": 0.0, "payment_terms": "LC", "vessel_flight": null, "inr_equivalent": 0.0, "invoice_number": "INV001", "_missing_fields": [{"field": "country_of_origin", "blocking": false, "question": "Please provide the country of origin for the basmati rice"}, {"field": "packing_instructions", "blocking": false, "question": "Please provide the packing instructions for the basmati rice"}, {"field": "buyer_address", "blocking": false, "question": "Please provide the address of the buyer"}, {"field": "port_of_loading", "blocking": false, "question": "Please provide the port of loading"}, {"field": "port_of_discharge", "blocking": false, "question": "Please provide the port of discharge"}, {"field": "country_of_buyer", "blocking": false, "question": "Please provide the country of the buyer"}, {"field": "vat_trn_of_buyer", "blocking": false, "question": "Please provide the VAT TRN of the buyer"}], "amount_in_words": "Two Thousand One Hundred Fifty US Dollars", "lut_bond_number": "LUT/Bond Number", "port_of_loading": "Port of Loading", "port_of_discharge": "Port of Discharge", "_lc_compliance_flags": [], "authorized_signatory": "Authorized Signatory", "country_of_final_destination": "Country of Buyer"}}	approved	00000000-0000-0000-0000-000000000002	00000000-0000-0000-0000-000000000002	2026-05-23 14:57:07.72149+00	test	2026-05-23 10:23:32.727852+00	2026-05-23 06:23:32.728914+00
e1376e54-32dc-47df-9b40-848caf6dc895	00000000-0000-0000-0000-000000000001	6ed40049-12da-4197-be3f-e1636270446b	\N	96cdc2ac-f0df-4d19-9b07-9ac0b59eae82	\N	hitl_supervisor_agent	PO Review Required — WA-6ED40049	Moderate confidence (45.0%) — flagging for optional review	45.00	[{"source": "hitl_decision", "message": "Confidence score (45%) is below the auto-approval threshold (60%)", "severity": "medium"}]	soft_review	\N	{"packing_list": {"pl_date": "2024-09-16", "summary": {"total_packages": 1, "total_volume_cbm": 0.012, "total_net_weight_kg": 2.5, "total_gross_weight_kg": 3.0}, "packages": [{"hs_code": "8471.30", "width_cm": 30, "height_cm": 10, "length_cm": 40, "pkg_number": 1, "volume_cbm": 0.012, "description": "Dell Lattitude 7420", "packing_type": "carton", "net_weight_kg": 2.5, "gross_weight_kg": 3.0, "marks_and_numbers": "Dell Lattitude 7420", "number_of_packages": 1, "quantity_per_package": 1}], "pl_number": "PL-001", "_confidence": 45.0, "special_flags": {"fragile": false, "dg_cargo": false, "ispm15_required": false, "refrigeration_required": false}, "_missing_fields": [{"field": "country_of_origin", "blocking": false, "question": "What is the country of origin for the Dell Lattitude 7420?"}, {"field": "packing_instructions", "blocking": false, "question": "What are the packing instructions for the Dell Lattitude 7420?"}], "invoice_reference": "INV-001"}, "commercial_invoice": {"gstin": "07ABC1234E1Z5", "items": [{"unit": "Unit", "sl_no": 1, "total": 1000.0, "hs_code": "84713010", "quantity": 1.0, "unit_price": 1000.0, "description": "Dell Lattitude 7420", "net_weight_kg": 1.0, "gross_weight_kg": 1.5, "country_of_origin": "Country of Origin"}], "freight": 100.0, "currency": "USD", "exporter": {"pan": "ABC1234E", "city": "New Delhi", "name": "ABC Exports", "gstin": "07ABC1234E1Z5", "ad_code": "AD123456", "country": "India", "iec_code": "IEC123456", "address_line1": "123, Main Street", "address_line2": "New Delhi"}, "importer": {"name": "Dhiraj Group", "address": "Buyer Address", "country": "Country of Buyer", "vat_trn": "VAT TRN of Buyer"}, "subtotal": 1000.0, "incoterms": "CIF", "insurance": 50.0, "_confidence": 50.0, "declaration": "We declare that this invoice shows the actual price of goods described.", "grand_total": 1150.0, "igst_amount": 0.0, "bank_details": {"iban": null, "ifsc": "IFSC", "branch": "Branch", "bank_name": "Bank Name", "swift_code": "SWIFT Code", "account_number": "Account Number"}, "invoice_date": "2024-09-16", "lc_reference": null, "pre_carriage": "Pre Carriage", "exchange_rate": 0.0, "other_charges": 0.0, "payment_terms": "LC", "vessel_flight": null, "inr_equivalent": 0.0, "invoice_number": "INV001", "_missing_fields": [{"field": "country_of_origin", "blocking": false, "question": "What is the country of origin for the Dell Lattitude 7420?"}, {"field": "packing_instructions", "blocking": false, "question": "What are the packing instructions for the Dell Lattitude 7420?"}, {"field": "buyer_address", "blocking": false, "question": "What is the address of the buyer?"}, {"field": "port_of_loading", "blocking": false, "question": "What is the port of loading?"}, {"field": "port_of_discharge", "blocking": false, "question": "What is the port of discharge?"}, {"field": "country_of_final_destination", "blocking": false, "question": "What is the country of final destination?"}, {"field": "pre_carriage", "blocking": false, "question": "What is the pre-carriage?"}, {"field": "vessel_flight", "blocking": false, "question": "What is the vessel/flight?"}, {"field": "lut_bond_number", "blocking": false, "question": "What is the LUT/Bond number?"}], "amount_in_words": "One Thousand One Hundred Fifty US Dollars", "lut_bond_number": "LUT/Bond Number", "port_of_loading": "Port of Loading", "port_of_discharge": "Port of Discharge", "_lc_compliance_flags": [], "authorized_signatory": "Authorized Signatory", "country_of_final_destination": "Country of Final Destination"}}	approved	00000000-0000-0000-0000-000000000002	00000000-0000-0000-0000-000000000002	2026-05-23 15:04:45.046989+00	Actioned via Agent Hub MVP	2026-05-23 14:44:15.612255+00	2026-05-23 10:44:15.612882+00
390b465a-b256-40e0-9ecd-bcaa44598c93	00000000-0000-0000-0000-000000000001	89f714b4-1382-4117-be0a-2357ada57c27	\N	eaae9fb7-7189-4ba2-a008-5e56f0d0b3a6	\N	hitl_supervisor_agent	PO Review Required — WA-89F714B4	Moderate confidence (45.0%) — flagging for optional review	45.00	[{"source": "hitl_decision", "message": "Confidence score (45%) is below the auto-approval threshold (60%)", "severity": "medium"}]	soft_review	\N	{"packing_list": {"pl_date": "2024-09-16", "summary": {"total_packages": 1, "total_volume_cbm": 0.012, "total_net_weight_kg": 2.5, "total_gross_weight_kg": 3.0}, "packages": [{"hs_code": "84713010", "width_cm": 30, "height_cm": 10, "length_cm": 40, "pkg_number": 1, "volume_cbm": 0.012, "description": "Dell Latitude 7420 Laptops", "packing_type": "carton", "net_weight_kg": 2.5, "gross_weight_kg": 3.0, "marks_and_numbers": "Dell Latitude 7420", "number_of_packages": 1, "quantity_per_package": 1}], "pl_number": "PL-001", "_confidence": 45.0, "special_flags": {"fragile": false, "dg_cargo": false, "ispm15_required": false, "refrigeration_required": false}, "_missing_fields": [{"field": "packing_instructions", "blocking": false, "question": "Are the laptops properly packaged and marked for export?"}], "invoice_reference": "INV-001"}, "commercial_invoice": {"gstin": "27AAAAA1234A1Z5", "items": [{"unit": "Unit", "sl_no": 1, "total": 1000.0, "hs_code": "84713010", "quantity": 1.0, "unit_price": 1000.0, "description": "Dell Latitude 7420 Laptops", "net_weight_kg": 5.0, "gross_weight_kg": 5.5, "country_of_origin": "India"}], "freight": 100.0, "currency": "USD", "exporter": {"pan": "AAAAA1234A", "city": "Mumbai", "name": "ABC Exports", "gstin": "27AAAAA1234A1Z5", "ad_code": "AD123456", "country": "India", "iec_code": "IEC123456", "address_line1": "123, Main Street", "address_line2": "Mumbai"}, "importer": {"name": "Dhiraj Group", "address": "PO Box 123, Dubai", "country": "United Arab Emirates", "vat_trn": ""}, "subtotal": 1000.0, "incoterms": "CIF", "insurance": 50.0, "_confidence": 60.0, "declaration": "We declare that this invoice shows the actual price of goods described.", "grand_total": 1150.0, "igst_amount": 0.0, "bank_details": {"iban": null, "ifsc": "SBIN0001234", "branch": "Mumbai Branch", "bank_name": "State Bank of India", "swift_code": "SBININBB", "account_number": "1234567890"}, "invoice_date": "2024-09-16", "lc_reference": null, "pre_carriage": "", "exchange_rate": 0.0, "other_charges": 0.0, "payment_terms": "Letter of Credit (LC)", "vessel_flight": null, "inr_equivalent": 0.0, "invoice_number": "INV001", "_missing_fields": [{"field": "packing_instructions", "blocking": false, "question": "Are the laptops properly packaged and marked for export?"}], "amount_in_words": "One Thousand One Hundred Fifty US Dollars only", "lut_bond_number": "LUT123456", "port_of_loading": "", "port_of_discharge": "Jebel Ali Port, Dubai", "_lc_compliance_flags": [], "authorized_signatory": "Authorized Signatory", "country_of_final_destination": "United Arab Emirates"}}	approved	00000000-0000-0000-0000-000000000002	00000000-0000-0000-0000-000000000002	2026-05-23 15:07:29.877719+00	Actioned via Agent Hub MVP	2026-05-23 14:26:02.803101+00	2026-05-23 10:26:02.80423+00
9718deb5-f5e2-44bd-aa11-21da8c142de7	00000000-0000-0000-0000-000000000001	271403d6-3473-4e10-8679-5f61d39fb47d	\N	37a6e3ec-b1b3-4017-86c8-3c1c91a77302	\N	hitl_supervisor_agent	PO Review Required — WA-271403D6	Moderate confidence (45.0%) — flagging for optional review	45.00	[{"source": "hitl_decision", "message": "Confidence score (45%) is below the auto-approval threshold (60%)", "severity": "medium"}]	soft_review	\N	{"packing_list": {"pl_date": "2024-09-16", "summary": {"total_packages": 1, "total_volume_cbm": 0.012, "total_net_weight_kg": 2.5, "total_gross_weight_kg": 3.0}, "packages": [{"hs_code": "8471.30", "width_cm": 30, "height_cm": 10, "length_cm": 40, "pkg_number": 1, "volume_cbm": 0.012, "description": "Dell Lattitude 7420", "packing_type": "carton", "net_weight_kg": 2.5, "gross_weight_kg": 3.0, "marks_and_numbers": "Dell Lattitude 7420", "number_of_packages": 1, "quantity_per_package": 1}], "pl_number": "PL-001", "_confidence": 45.0, "special_flags": {"fragile": false, "dg_cargo": false, "ispm15_required": false, "refrigeration_required": false}, "_missing_fields": [{"field": "country_of_origin", "blocking": false, "question": "What is the country of origin for the Dell Lattitude 7420?"}, {"field": "packing_instructions", "blocking": false, "question": "What are the packing instructions for the Dell Lattitude 7420?"}], "invoice_reference": "INV-001"}, "commercial_invoice": {"gstin": "GSTIN123456", "items": [{"unit": "Unit", "sl_no": 1, "total": 1000.0, "hs_code": "84713010", "quantity": 1.0, "unit_price": 1000.0, "description": "Dell Lattitude 7420", "net_weight_kg": 1.0, "gross_weight_kg": 1.0, "country_of_origin": "Country of Origin Not Provided"}], "freight": 100.0, "currency": "USD", "exporter": {"pan": "PAN123456", "city": "New York", "name": "ABC Exports", "gstin": "GSTIN123456", "ad_code": "AD123456", "country": "USA", "iec_code": "IEC123456", "address_line1": "123 Main Street", "address_line2": "New York"}, "importer": {"name": "Dhiraj Group", "address": "Buyer Address Not Provided", "country": "Country Not Provided", "vat_trn": "VAT/TRN Not Provided"}, "subtotal": 1000.0, "incoterms": "CIF", "insurance": 50.0, "_confidence": 50.0, "declaration": "We declare that this invoice shows the actual price of goods described.", "grand_total": 1150.0, "igst_amount": 0.0, "bank_details": {"iban": null, "ifsc": "IFSC Not Provided", "branch": "Branch Not Provided", "bank_name": "Bank Name Not Provided", "swift_code": "SWIFT Code Not Provided", "account_number": "Account Number Not Provided"}, "invoice_date": "2024-09-16", "lc_reference": null, "pre_carriage": "Not Applicable", "exchange_rate": 0.0, "other_charges": 0.0, "payment_terms": "LC", "vessel_flight": null, "inr_equivalent": 0.0, "invoice_number": "INV001", "_missing_fields": [{"field": "buyer_address", "blocking": false, "question": "What is the address of the buyer?"}, {"field": "country_of_origin", "blocking": false, "question": "What is the country of origin for the Dell Lattitude 7420?"}, {"field": "packing_instructions", "blocking": false, "question": "What are the packing instructions for the Dell Lattitude 7420?"}, {"field": "port_of_loading", "blocking": false, "question": "What is the port of loading?"}, {"field": "port_of_discharge", "blocking": false, "question": "What is the port of discharge?"}, {"field": "country_of_final_destination", "blocking": false, "question": "What is the country of final destination?"}, {"field": "lc_number", "blocking": false, "question": "What is the LC number?"}, {"field": "issuing_bank", "blocking": false, "question": "What is the issuing bank?"}, {"field": "expiry_date", "blocking": false, "question": "What is the expiry date?"}, {"field": "bank_details", "blocking": false, "question": "What are the bank details?"}, {"field": "authorized_signatory", "blocking": false, "question": "Who is the authorized signatory?"}], "amount_in_words": "One Thousand One Hundred Fifty USD", "lut_bond_number": "LUT/Bond Number Not Provided", "port_of_loading": "Port of Loading Not Provided", "port_of_discharge": "Port of Discharge Not Provided", "_lc_compliance_flags": ["LC Number Not Provided", "Issuing Bank Not Provided", "Expiry Date Not Provided"], "authorized_signatory": "Authorized Signatory Not Provided", "country_of_final_destination": "Country of Final Destination Not Provided"}}	approved	00000000-0000-0000-0000-000000000002	00000000-0000-0000-0000-000000000002	2026-05-24 12:10:05.61405+00	Actioned via Agent Hub MVP	2026-05-24 12:41:48.031028+00	2026-05-24 08:41:48.031942+00
fa000000-0000-0000-0000-000000000001	00000000-0000-0000-0000-000000000001	ef000000-0000-0000-0000-000000000002	\N	a1000000-0000-0000-0000-000000000002	d1000000-0000-0000-0000-000000000004	hitl_evaluation	Moderate confidence — Payment terms clarification needed	PO received via WhatsApp from Gulf Fresh General Trading. AI confidence 72%. Payment terms "TT 30 days" detected but LC field was left ambiguous. HS code 1006302000 validated (India→UAE, free export). Document generated but requires human sign-off before dispatch.	72.00	[{"message": "Payment terms unclear — TT vs LC ambiguity detected", "severity": "medium"}, {"message": "Buyer address not provided — invoice may need correction", "severity": "low"}]	Review payment terms and confirm buyer address before approving dispatch.	{"total_amount": 14700.00, "buyer_address": null, "payment_terms": "TT"}	{"total_amount": 14700.00, "buyer_address": "Shop 12, Al Barsha Souk, Abu Dhabi", "payment_terms": "TT 30 days after BL date"}	approved	00000000-0000-0000-0000-000000000002	00000000-0000-0000-0000-000000000002	2026-05-23 14:58:58.195344+00	Actioned via Agent Hub MVP	2026-05-23 08:41:50.068651+00	2026-05-23 02:01:50.068651+00
65ebf344-b601-4ee4-abcc-6e7846b7d26f	00000000-0000-0000-0000-000000000001	21fefa83-b1bf-43a3-b0d8-03dec8de4bed	\N	09919ecf-a938-4713-a1e6-80d3a6f94ce0	\N	hitl_supervisor_agent	PO Review Required — WA-21FEFA83	Moderate confidence (55.0%) — flagging for optional review	55.00	[{"source": "hitl_decision", "message": "Confidence score (55%) is below the auto-approval threshold (60%)", "severity": "medium"}]	soft_review	\N	{"packing_list": {"_draft": true, "pl_number": "PL-21FEFA83", "_confidence": 60.0, "total_packages": 1, "total_volume_cbm": 0, "total_net_weight_kg": 0, "total_gross_weight_kg": 0}, "commercial_invoice": {"gstin": "27AABCA1234C1Z5", "items": [{"unit": "Units", "sl_no": 1, "total": 30000.0, "hs_code": "84713010", "quantity": 100, "unit_price": 300.0, "description": "Dell Latitude 7420 Laptops", "net_weight_kg": 130.0, "gross_weight_kg": 155.0, "country_of_origin": "India"}], "freight": 0.0, "currency": "USD", "exporter": {"pan": "Not Provided", "city": "Mumbai", "name": "AGRO EXPORTS INDIA PVT. LTD.", "gstin": "27AABCA1234C1Z5", "ad_code": "Not Provided", "country": "India", "iec_code": "Not Provided", "address_line1": "123, Nariman Point", "address_line2": "Mumbai – 400021, Maharashtra"}, "importer": {"name": "AGRO EXPORTS INDIA PVT. LTD.", "address": "123, Nariman Point, Mumbai – 400021, Maharashtra, India", "country": "India", "vat_trn": "GSTIN: 27AABCA1234C1Z5"}, "subtotal": 30000.0, "incoterms": "CIF – Jebel Ali Port, Dubai (UAE)", "insurance": 0.0, "_confidence": 55.0, "declaration": "We declare that this invoice shows the actual price of goods described.", "grand_total": 30000.0, "igst_amount": 0.0, "bank_details": {"iban": null, "ifsc": "Not Provided", "branch": "Not Provided", "bank_name": "Not Provided", "swift_code": "Not Provided", "account_number": "Not Provided"}, "invoice_date": "2024-09-16", "lc_reference": "LC-987654321", "pre_carriage": "Not Provided", "exchange_rate": 0.0, "other_charges": 0.0, "payment_terms": "Letter of Credit (LC)", "vessel_flight": null, "inr_equivalent": 0.0, "invoice_number": "INV001", "_missing_fields": [{"field": "IEC Code", "blocking": false, "question": "What is the exporter's IEC code?"}, {"field": "AD Code", "blocking": false, "question": "What is the exporter's AD code?"}, {"field": "PAN", "blocking": false, "question": "What is the exporter's PAN?"}, {"field": "Port of Loading", "blocking": false, "question": "What is the port of loading?"}, {"field": "Pre-carriage", "blocking": false, "question": "What is the pre-carriage?"}, {"field": "Bank Details", "blocking": false, "question": "What are the exporter's bank details?"}, {"field": "Authorized Signatory", "blocking": false, "question": "Who is the authorized signatory?"}], "amount_in_words": "Thirty Thousand US Dollars Only", "lut_bond_number": null, "port_of_loading": "Not Provided", "port_of_discharge": "Jebel Ali Port", "_lc_compliance_flags": ["LC number provided", "LC expiry date provided", "Incoterms provided"], "authorized_signatory": "Not Provided", "country_of_final_destination": "UAE"}}	rejected	00000000-0000-0000-0000-000000000002	00000000-0000-0000-0000-000000000002	2026-05-27 13:56:20.68728+00	Actioned via Agent Hub MVP	2026-05-27 10:29:11.800849+00	2026-05-27 06:29:11.798237+00
093b6f2f-35f8-44dd-a082-8df131c8ab83	00000000-0000-0000-0000-000000000001	dd300701-c9ad-478e-bc6c-33623d27b9bb	\N	d1829d06-4954-4ca9-bfeb-1caf946a4a41	\N	hitl_supervisor_agent	PO Review Required — WA-DD300701	Moderate confidence (45.0%) — flagging for optional review	45.00	[{"source": "hs_validation", "message": "BIS compliance check required", "severity": "medium"}, {"source": "hs_validation", "message": "WPC ETA required for wireless modules", "severity": "medium"}, {"source": "hs_validation", "message": "VAT applicable in UAE (5%)", "severity": "medium"}, {"source": "hitl_decision", "message": "Confidence score (45%) is below the auto-approval threshold (60%)", "severity": "medium"}]	soft_review	\N	{"packing_list": {"pl_date": "2024-09-16", "summary": {"total_packages": 3, "total_volume_cbm": 0.045, "total_net_weight_kg": 4.5, "total_gross_weight_kg": 6.0}, "packages": [{"hs_code": "84713010", "width_cm": 30, "height_cm": 10, "length_cm": 50, "pkg_number": 1, "volume_cbm": 0.015, "description": "Dell Latitude 7420 Laptops", "packing_type": "carton", "net_weight_kg": 1.5, "gross_weight_kg": 2.0, "marks_and_numbers": "Dell Latitude 7420", "number_of_packages": 3, "quantity_per_package": 10}], "pl_number": "PL-001", "_confidence": 45.0, "special_flags": {"fragile": false, "dg_cargo": false, "ispm15_required": false, "refrigeration_required": false}, "_missing_fields": [{"field": "Encryption", "blocking": false, "question": "Do the laptops contain high-level encryption software that falls under SCOMET Category 5 (Information Security)?"}, {"field": "Packing Instructions", "blocking": false, "question": "Please provide detailed packing instructions for the laptops."}], "invoice_reference": "LC-987654321"}, "commercial_invoice": {"gstin": "PENDING_INPUT", "items": [{"unit": "PCS", "sl_no": 1, "total": 30000.0, "hs_code": "84713000", "quantity": 100.0, "unit_price": 300.0, "description": "Dell Latitude 7420 Laptops", "net_weight_kg": 150.0, "gross_weight_kg": 200.0, "country_of_origin": "India"}], "freight": 0.0, "currency": "USD", "exporter": {"pan": "PENDING_INPUT", "city": "New Delhi", "name": "TechSource India Pvt Ltd", "gstin": "PENDING_INPUT", "ad_code": "PENDING_INPUT", "country": "India", "iec_code": "PENDING_INPUT", "address_line1": "123 Industrial Estate", "address_line2": "Okhla Phase III"}, "importer": {"name": "Dhiraj Group", "address": "456 Business Avenue, Business Bay, Dubai, United Arab Emirates", "country": "United Arab Emirates", "vat_trn": "100293847563"}, "subtotal": 30000.0, "incoterms": "CIF Jebel Ali Port, Dubai", "insurance": 0.0, "_confidence": 60.0, "declaration": "We declare that this invoice shows the actual price of goods described.", "grand_total": 30000.0, "igst_amount": 0.0, "bank_details": {"iban": null, "ifsc": "SBIN0000000", "branch": "Corporate Branch, New Delhi", "bank_name": "State Bank of India", "swift_code": "SBININBBXXX", "account_number": "XXXXXXXXXXXX"}, "invoice_date": "2024-05-22", "lc_reference": "LC-987654321 | Issuing Bank: Emirates NBD Dubai | Expiry: 2026-12-31", "pre_carriage": "By Sea", "exchange_rate": 83.5, "other_charges": 0.0, "payment_terms": "Letter of Credit (LC)", "vessel_flight": null, "inr_equivalent": 2505000.0, "invoice_number": "EXP/2024/001", "_missing_fields": [{"field": "Exporter Details", "blocking": true, "question": "Please provide IEC, GSTIN, PAN, and AD Code for the exporter."}, {"field": "LUT/Bond", "blocking": true, "question": "Please provide the LUT/Bond reference number for zero-rated GST supply."}, {"field": "Encryption", "blocking": false, "question": "Do the laptops contain high-level encryption software that falls under SCOMET Category 5 (Information Security)?"}], "amount_in_words": "Thirty Thousand US Dollars Only", "lut_bond_number": "PENDING_INPUT", "port_of_loading": "Nhava Sheva Port, India", "port_of_discharge": "Jebel Ali Port, Dubai", "_lc_compliance_flags": ["LC Number included", "Expiry date included", "Description matches LC terms"], "authorized_signatory": "Authorized Signatory", "country_of_final_destination": "United Arab Emirates"}}	approved	00000000-0000-0000-0000-000000000002	00000000-0000-0000-0000-000000000002	2026-05-23 15:04:32.665908+00	Actioned via Agent Hub MVP	2026-05-23 19:04:22.054806+00	2026-05-23 15:04:22.05587+00
fbebb122-5a3f-478f-b339-478b04650af8	00000000-0000-0000-0000-000000000001	240c464a-825a-4b00-a426-ee9e1f9d8329	\N	97c24140-a8a5-4c28-b421-67a45b7b3895	\N	hitl_supervisor_agent	PO Review Required — WA-240C464A	Confidence 40.0% below threshold (45.0%)	40.00	[{"source": "hs_validation", "message": "HS code mismatch", "severity": "medium"}, {"source": "hitl_decision", "message": "Confidence score (40%) is below the auto-approval threshold (60%)", "severity": "medium"}]	require_human	\N	{"packing_list": {"pl_date": "2024-09-16", "summary": {"total_packages": 10, "total_volume_cbm": 1.5, "total_net_weight_kg": 200.0, "total_gross_weight_kg": 220.0}, "packages": [{"hs_code": "10063000", "width_cm": 50, "height_cm": 30, "length_cm": 100, "pkg_number": 1, "volume_cbm": 0.15, "description": "Rice", "packing_type": "bag", "net_weight_kg": 20.0, "gross_weight_kg": 22.0, "marks_and_numbers": "RICE-001", "number_of_packages": 10, "quantity_per_package": 1000}], "pl_number": "PL001", "_confidence": 45.0, "special_flags": {"fragile": false, "dg_cargo": false, "ispm15_required": false, "refrigeration_required": false}, "_missing_fields": [{"field": "packing_instructions", "blocking": true, "question": "Please provide detailed packing instructions for the shipment."}, {"field": "hs_code", "blocking": true, "question": "Please confirm the correct HS code for the product 'Rice'."}], "invoice_reference": "INV001"}, "commercial_invoice": {"gstin": "27AAAAA1234A1Z5", "items": [{"unit": "Kg", "sl_no": 1, "total": 1000.0, "hs_code": "10063000", "quantity": 1000.0, "unit_price": 1.0, "description": "Rice", "net_weight_kg": 1000.0, "gross_weight_kg": 1000.0, "country_of_origin": "India"}], "freight": 100.0, "currency": "USD", "exporter": {"pan": "AAAAA1234A", "city": "Mumbai", "name": "ABC Exports", "gstin": "27AAAAA1234A1Z5", "ad_code": "AD123456", "country": "India", "iec_code": "IEC123456", "address_line1": "123, Main Street", "address_line2": "Mumbai"}, "importer": {"name": "Buyer Name", "address": "Buyer Address", "country": "United Arab Emirates", "vat_trn": ""}, "subtotal": 1000.0, "incoterms": "CIF", "insurance": 50.0, "_confidence": 50.0, "declaration": "We declare that this invoice shows the actual price of goods described.", "grand_total": 1150.0, "igst_amount": 0.0, "bank_details": {"iban": null, "ifsc": "SBIN0001234", "branch": "Mumbai", "bank_name": "State Bank of India", "swift_code": "SBININBB", "account_number": "1234567890"}, "invoice_date": "2024-09-16", "lc_reference": null, "pre_carriage": "", "exchange_rate": 0.0, "other_charges": 0.0, "payment_terms": "LC", "vessel_flight": null, "inr_equivalent": 0.0, "invoice_number": "INV001", "_missing_fields": [{"field": "buyer_name", "blocking": true, "question": "Please provide the buyer's name."}, {"field": "buyer_address", "blocking": true, "question": "Please provide the buyer's address."}, {"field": "lc_details", "blocking": true, "question": "Please provide the LC details."}], "amount_in_words": "One Thousand One Hundred Fifty US Dollars", "lut_bond_number": "LUT123456", "port_of_loading": "JNPT", "port_of_discharge": "Jebel Ali Port", "_lc_compliance_flags": [], "authorized_signatory": "Authorized Signatory", "country_of_final_destination": "United Arab Emirates"}}	rejected	00000000-0000-0000-0000-000000000002	00000000-0000-0000-0000-000000000002	2026-05-27 13:56:22.632825+00	Actioned via Agent Hub MVP	2026-05-27 08:49:32.776154+00	2026-05-27 04:49:32.777924+00
4a905d6a-9c74-4ac4-ab2a-8a4e38d5ebe9	00000000-0000-0000-0000-000000000001	3c7d209a-a09b-4d0b-90d2-edd4bcecbc20	\N	ea835eb6-8e90-4cb2-ae2d-50dbf414787a	\N	hitl_supervisor_agent	PO Review Required — WA-3C7D209A	Moderate confidence (55.0%) — flagging for optional review	55.00	[{"source": "hs_validation", "message": "BIS compliance required for India export", "severity": "medium"}, {"source": "hs_validation", "message": "WPC ETA required for wireless modules", "severity": "medium"}, {"source": "hs_validation", "message": "Zero-rated GST export (LUT/Bond required)", "severity": "medium"}, {"source": "hitl_decision", "message": "Confidence score (55%) is below the auto-approval threshold (60%)", "severity": "medium"}]	soft_review	\N	{"packing_list": {"pl_date": "2024-09-16", "summary": {"total_packages": 10, "total_volume_cbm": 0.72, "total_net_weight_kg": 25.0, "total_gross_weight_kg": 30.0}, "packages": [{"hs_code": "84713010", "width_cm": 40, "height_cm": 30, "length_cm": 60, "pkg_number": 1, "volume_cbm": 0.072, "description": "Dell Latitude 7420 Laptops", "packing_type": "carton", "net_weight_kg": 2.5, "gross_weight_kg": 3.0, "marks_and_numbers": "Dhiraj Group, Dubai", "number_of_packages": 10, "quantity_per_package": 10}], "pl_number": "PL-001", "_confidence": 60.0, "special_flags": {"fragile": false, "dg_cargo": false, "ispm15_required": false, "refrigeration_required": false}, "_missing_fields": [{"field": "WPC/BIS", "blocking": false, "question": "Do you have valid BIS CRS registration and WPC ETA certificates for this specific model?"}], "invoice_reference": "LC-987654321"}, "commercial_invoice": {"gstin": "PENDING_INPUT", "items": [{"unit": "PCS", "sl_no": 1, "total": 30000.0, "hs_code": "84713000", "quantity": 100.0, "unit_price": 300.0, "description": "Dell Latitude 7420 Laptops", "net_weight_kg": 150.0, "gross_weight_kg": 200.0, "country_of_origin": "India"}], "freight": 0.0, "currency": "USD", "exporter": {"pan": "PENDING_INPUT", "city": "Mumbai", "name": "TechSource India Pvt Ltd", "gstin": "PENDING_INPUT", "ad_code": "PENDING_INPUT", "country": "India", "iec_code": "PENDING_INPUT", "address_line1": "123 Industrial Estate", "address_line2": "Andheri East, Mumbai"}, "importer": {"name": "Dhiraj Group", "address": "456 Business Avenue, Business Bay, Dubai, United Arab Emirates", "country": "United Arab Emirates", "vat_trn": "100293847563"}, "subtotal": 30000.0, "incoterms": "CIF Jebel Ali Port, Dubai", "insurance": 0.0, "_confidence": 55.0, "declaration": "We declare that this invoice shows the actual price of goods described.", "grand_total": 30000.0, "igst_amount": 0.0, "bank_details": {"iban": null, "ifsc": "SBIN0000000", "branch": "Corporate Branch, Mumbai", "bank_name": "State Bank of India", "swift_code": "SBININBBXXX", "account_number": "00000000000000"}, "invoice_date": "2024-05-22", "lc_reference": "LC-987654321 | Issuing Bank: Emirates NBD Dubai | Expiry: 2026-12-31", "pre_carriage": "By Sea", "exchange_rate": 83.5, "other_charges": 0.0, "payment_terms": "Letter of Credit (LC)", "vessel_flight": null, "inr_equivalent": 2505000.0, "invoice_number": "EXP/2024/001", "_missing_fields": [{"field": "IEC/GSTIN/AD Code", "blocking": true, "question": "Please provide your IEC, GSTIN, and AD Code for mandatory India export compliance."}, {"field": "LUT/Bond Reference", "blocking": true, "question": "Please provide the LUT/Bond reference number for zero-rated IGST supply."}, {"field": "WPC/BIS", "blocking": false, "question": "Do you have valid BIS CRS registration and WPC ETA certificates for this specific model?"}], "amount_in_words": "Thirty Thousand US Dollars Only", "lut_bond_number": "PENDING_INPUT", "port_of_loading": "Nhava Sheva Port, India", "port_of_discharge": "Jebel Ali Port, Dubai", "_lc_compliance_flags": ["Description matches LC", "LC Number and Bank details included"], "authorized_signatory": "Authorized Signatory", "country_of_final_destination": "United Arab Emirates"}}	approved	00000000-0000-0000-0000-000000000002	00000000-0000-0000-0000-000000000002	2026-05-23 15:32:54.001862+00	Actioned via Agent Hub MVP	2026-05-23 19:32:26.455698+00	2026-05-23 15:32:26.456909+00
403b6e3c-ac88-4b50-8a7d-6eb415253151	00000000-0000-0000-0000-000000000001	f46c42a3-0dc2-47aa-95d9-babbaf9ec983	\N	50c71ab2-119d-49c5-aceb-57793b817563	\N	hitl_supervisor_agent	PO Review Required — WA-F46C42A3	High-severity flags: ['Automated compliance checks failed/timed out. Manual verification of HS codes and regulations required.']	45.00	[{"source": "hs_validation", "message": "Automated compliance checks failed/timed out. Manual verification of HS codes and regulations required.", "severity": "high"}, {"source": "hitl_decision", "message": "Confidence score (45%) is below the auto-approval threshold (60%)", "severity": "medium"}]	require_human	\N	{"packing_list": {"_draft": true, "pl_number": "PL-F46C42A3", "_confidence": 60.0, "total_packages": 1, "total_volume_cbm": 0, "total_net_weight_kg": 0, "total_gross_weight_kg": 0}, "commercial_invoice": {"items": [{"qty": 130.0, "unit": "KG", "description": "Rice"}], "_draft": true, "currency": "USD", "importer": {"name": null}, "incoterms": "CIF", "_confidence": 60.0, "declaration": "Draft — pending review.", "grand_total": 30000.0, "bank_details": {"name": "State Bank of India", "swift": "SBININBB"}, "invoice_date": "2026-05-27", "payment_terms": "LC", "invoice_number": "DRAFT-F46C42A3", "port_of_discharge": "Jebel Ali Port"}}	rejected	00000000-0000-0000-0000-000000000002	00000000-0000-0000-0000-000000000002	2026-05-27 13:56:24.53386+00	Actioned via Agent Hub MVP	2026-05-27 07:21:07.845641+00	2026-05-27 03:21:07.849568+00
7d9cde59-6841-48d1-8a95-6c6824f1bd2b	00000000-0000-0000-0000-000000000001	976e67cd-9269-4693-9a58-b7d1e0c2a2f7	\N	2c2a1e04-0887-4e31-8aed-759d5acbe823	\N	hitl_supervisor_agent	PO Review Required — WA-976E67CD	Moderate confidence (45.0%) — flagging for optional review	45.00	[{"source": "hs_validation", "message": "BIS compliance required for India export", "severity": "medium"}, {"source": "hs_validation", "message": "WPC ETA required for wireless modules", "severity": "medium"}, {"source": "hs_validation", "message": "Zero-rated GST export (LUT/Bond required)", "severity": "medium"}, {"source": "hitl_decision", "message": "Confidence score (45%) is below the auto-approval threshold (60%)", "severity": "medium"}]	soft_review	\N	{"packing_list": {"pl_date": "2023-10-27", "summary": {"total_packages": 10, "total_volume_cbm": 0.6, "total_net_weight_kg": 130.0, "total_gross_weight_kg": 160.0}, "packages": [{"hs_code": "84713000", "width_cm": 40, "height_cm": 30, "length_cm": 50, "pkg_number": 1, "volume_cbm": 0.06, "description": "Dell Latitude 7420 Laptops", "packing_type": "carton", "net_weight_kg": 13.0, "gross_weight_kg": 16.0, "marks_and_numbers": "DG-DXB-001-010", "number_of_packages": 10, "quantity_per_package": 10}], "pl_number": "PL-2023-001", "_confidence": 45.0, "special_flags": {"fragile": true, "dg_cargo": false, "ispm15_required": false, "refrigeration_required": false}, "_missing_fields": [{"field": "unit_weights", "blocking": false, "question": "The provided data lacks specific unit weights for the Dell Latitude 7420. Estimated weights (1.3kg net/1.6kg gross per unit) were used. Please confirm actual weights."}, {"field": "dimensions", "blocking": false, "question": "Standard carton dimensions were estimated for 10 units. Please confirm actual master carton dimensions."}, {"field": "WPC/BIS", "blocking": false, "question": "Do you have valid BIS CRS registration and WPC ETA certificates for this specific model?"}], "invoice_reference": "LC-987654321"}, "commercial_invoice": {"gstin": "PENDING_INPUT", "items": [{"unit": "PCS", "sl_no": 1, "total": 30000.0, "hs_code": "84713000", "quantity": 100.0, "unit_price": 300.0, "description": "Dell Latitude 7420 Laptops", "net_weight_kg": 150.0, "gross_weight_kg": 200.0, "country_of_origin": "India"}], "freight": 0.0, "currency": "USD", "exporter": {"pan": "PENDING_INPUT", "city": "Mumbai", "name": "TechSource India Pvt Ltd", "gstin": "PENDING_INPUT", "ad_code": "PENDING_INPUT", "country": "India", "iec_code": "PENDING_INPUT", "address_line1": "123 Industrial Estate", "address_line2": "Andheri East, Mumbai"}, "importer": {"name": "Dhiraj Group", "address": "456 Business Avenue, Business Bay, Dubai, United Arab Emirates", "country": "United Arab Emirates", "vat_trn": "100293847563"}, "subtotal": 30000.0, "incoterms": "CIF Jebel Ali Port, Dubai", "insurance": 0.0, "_confidence": 55.0, "declaration": "We declare that this invoice shows the actual price of goods described.", "grand_total": 30000.0, "igst_amount": 0.0, "bank_details": {"iban": null, "ifsc": "SBIN0000000", "branch": "Corporate Branch, Mumbai", "bank_name": "State Bank of India", "swift_code": "SBININBBXXX", "account_number": "00000000000000"}, "invoice_date": "2024-05-22", "lc_reference": "LC-987654321 | Issuing Bank: Emirates NBD Dubai | Expiry: 2026-12-31", "pre_carriage": "By Sea", "exchange_rate": 83.5, "other_charges": 0.0, "payment_terms": "Letter of Credit (LC)", "vessel_flight": null, "inr_equivalent": 2505000.0, "invoice_number": "EXP/2024/001", "_missing_fields": [{"field": "IEC/GSTIN/AD Code", "blocking": true, "question": "Please provide your IEC, GSTIN, and AD Code for mandatory India export compliance."}, {"field": "LUT/Bond Reference", "blocking": true, "question": "Please provide the LUT/Bond reference number for zero-rated IGST supply."}, {"field": "WPC/BIS", "blocking": false, "question": "Do you have valid BIS CRS registration and WPC ETA certificates for this specific model?"}], "amount_in_words": "Thirty Thousand US Dollars Only", "lut_bond_number": "PENDING_INPUT", "port_of_loading": "Nhava Sheva Port, India", "port_of_discharge": "Jebel Ali Port, Dubai", "_lc_compliance_flags": ["Description matches LC", "LC Number and Bank details included"], "authorized_signatory": "Authorized Signatory", "country_of_final_destination": "United Arab Emirates"}}	approved	00000000-0000-0000-0000-000000000002	00000000-0000-0000-0000-000000000002	2026-05-23 15:59:12.535718+00	Actioned via Agent Hub MVP	2026-05-23 19:58:06.756601+00	2026-05-23 15:58:06.757658+00
d1b7f3ad-f929-4b2e-9188-bcb1aa5a19a0	5359c3a9-2913-48b8-888c-00fbfd84682f	6207f055-1ad7-4ddf-9b34-6cf4b2610286	\N	22c3790e-999d-41a4-a9f6-a3154ce1f5cc	\N	hitl_supervisor_agent	PO Review Required — WA-6207F055	Moderate confidence (45.0%) — flagging for optional review	45.00	[{"source": "hitl_decision", "message": "Confidence score (45%) is below the auto-approval threshold (60%)", "severity": "medium"}]	soft_review	\N	{"packing_list": {"pl_date": "2024-09-16", "summary": {"total_packages": 1000, "total_volume_cbm": 15.12, "total_net_weight_kg": 25000.0, "total_gross_weight_kg": 26050.0}, "packages": [{"hs_code": "1006.30.10", "width_cm": 50, "height_cm": 30, "length_cm": 100, "pkg_number": 1, "volume_cbm": 0.15, "description": "Basmati Rice – Grade A Extra Long Grain (1121 Variety, Aged 2 Years, Sortex Cleaned)", "packing_type": "bag", "net_weight_kg": 25.0, "gross_weight_kg": 26.0, "marks_and_numbers": "Product Name, Net/Gross Wt, Batch No., MFG Date", "number_of_packages": 400, "quantity_per_package": 25}, {"hs_code": "1006.30.10", "width_cm": 50, "height_cm": 30, "length_cm": 100, "pkg_number": 2, "volume_cbm": 0.15, "description": "Basmati Rice – Grade B Long Grain (Pusa 1121, Non-Aged)", "packing_type": "bag", "net_weight_kg": 25.0, "gross_weight_kg": 26.0, "marks_and_numbers": "Product Name, Net/Gross Wt, Batch No., MFG Date", "number_of_packages": 300, "quantity_per_package": 25}, {"hs_code": "1006.40.00", "width_cm": 50, "height_cm": 30, "length_cm": 100, "pkg_number": 3, "volume_cbm": 0.15, "description": "Broken Basmati Rice (5% Brokens)", "packing_type": "bag", "net_weight_kg": 25.0, "gross_weight_kg": 26.0, "marks_and_numbers": "Product Name, Net/Gross Wt, Batch No., MFG Date", "number_of_packages": 200, "quantity_per_package": 25}, {"hs_code": "1514.19.00", "width_cm": 20, "height_cm": 20, "length_cm": 30, "pkg_number": 4, "volume_cbm": 0.012, "description": "Rice Bran Oil – Refined (Edible Grade, 15 kg Tins) Certification: FSSAI & Halal", "packing_type": "tin", "net_weight_kg": 15.0, "gross_weight_kg": 16.5, "marks_and_numbers": "Product Name, Net/Gross Wt, Batch No., MFG Date", "number_of_packages": 100, "quantity_per_package": 1}], "pl_number": "PL001", "_confidence": 60.0, "special_flags": {"fragile": false, "dg_cargo": false, "ispm15_required": false, "refrigeration_required": false}, "_missing_fields": [{"field": "exact dimensions of each package", "blocking": false, "question": "Can you provide the exact dimensions of each package?"}, {"field": "weight of each package", "blocking": false, "question": "Can you provide the weight of each package?"}], "invoice_reference": "INV001"}, "commercial_invoice": {"gstin": "[GSTIN REQUIRED]", "items": [{"unit": "MT", "sl_no": 1, "total": 0.0, "hs_code": "1006.30.10", "quantity": 0.0, "unit_price": 0.0, "description": "Basmati Rice – Grade A Extra Long Grain (1121 Variety, Aged 2 Years, Sortex Cleaned)", "net_weight_kg": 0.0, "gross_weight_kg": 0.0, "country_of_origin": "India"}, {"unit": "MT", "sl_no": 2, "total": 0.0, "hs_code": "1006.30.10", "quantity": 0.0, "unit_price": 0.0, "description": "Basmati Rice – Grade B Long Grain (Pusa 1121, Non-Aged)", "net_weight_kg": 0.0, "gross_weight_kg": 0.0, "country_of_origin": "India"}, {"unit": "MT", "sl_no": 3, "total": 0.0, "hs_code": "1006.40.00", "quantity": 0.0, "unit_price": 0.0, "description": "Broken Basmati Rice (5% Brokens)", "net_weight_kg": 0.0, "gross_weight_kg": 0.0, "country_of_origin": "India"}, {"unit": "TINS", "sl_no": 4, "total": 0.0, "hs_code": "1514.19.00", "quantity": 0.0, "unit_price": 0.0, "description": "Rice Bran Oil – Refined (Edible Grade, 15 kg Tins) Certification: FSSAI & Halal", "net_weight_kg": 0.0, "gross_weight_kg": 0.0, "country_of_origin": "India"}], "freight": 0.0, "currency": "USD", "exporter": {"pan": "[PAN REQUIRED]", "city": "[CITY REQUIRED]", "name": "[EXPORTER NAME REQUIRED]", "gstin": "[GSTIN REQUIRED]", "ad_code": "[AD CODE REQUIRED]", "country": "India", "iec_code": "[IEC NUMBER REQUIRED]", "address_line1": "[ADDRESS LINE 1 REQUIRED]", "address_line2": "[ADDRESS LINE 2 REQUIRED]"}, "importer": {"name": "AL NOOR FOODSTUFF TRADING LLC", "address": "P.O. Box 47823, Deira, Dubai, United Arab Emirates", "country": "United Arab Emirates", "vat_trn": "100358291200003"}, "subtotal": 0.0, "incoterms": "CIF – Jebel Ali Port, Dubai (UAE)", "insurance": 0.0, "_confidence": 45.0, "declaration": "We declare that this invoice shows the actual price of goods described.", "grand_total": 0.0, "igst_amount": 0.0, "bank_details": {"iban": null, "ifsc": "[IFSC REQUIRED]", "branch": "[BRANCH REQUIRED]", "bank_name": "[BANK NAME REQUIRED]", "swift_code": "[SWIFT CODE REQUIRED]", "account_number": "[ACCOUNT NUMBER REQUIRED]"}, "invoice_date": "2024-05-22", "lc_reference": null, "pre_carriage": "[PRE-CARRIAGE REQUIRED]", "exchange_rate": 0.0, "other_charges": 0.0, "payment_terms": "Irrevocable LC at Sight (SWIFT MT700)", "vessel_flight": null, "inr_equivalent": 0.0, "invoice_number": "EXP/2024/001", "_missing_fields": [{"field": "lc_number", "blocking": true, "question": "Please provide the LC Number as per SWIFT MT700."}, {"field": "exporter_details", "blocking": true, "question": "Please provide full exporter address, IEC, GSTIN, and AD Code."}, {"field": "quantity_and_price", "blocking": true, "question": "Please provide quantities and unit prices for all line items."}], "amount_in_words": "ZERO USD ONLY", "lut_bond_number": "[LUT/BOND REFERENCE REQUIRED]", "port_of_loading": "[PORT OF LOADING REQUIRED]", "port_of_discharge": "Jebel Ali Port, Dubai", "_lc_compliance_flags": ["LC Number missing", "LC Expiry Date missing", "LC Amount missing"], "authorized_signatory": "[NAME/DESIGNATION REQUIRED]", "country_of_final_destination": "United Arab Emirates"}}	rejected	00000000-0000-0000-0000-000000000002	00abb788-21e2-4703-807c-d6e93e04a2c9	2026-05-29 12:51:53.276536+00	Actioned via Agent Hub MVP	2026-05-29 16:51:40.855998+00	2026-05-29 12:51:40.85679+00
3c4408b9-2f21-4d19-acf9-93b7efd80a7f	005d0831-36c7-4d44-bb52-6d9a13bacb4d	32268ef0-d5ed-49b5-8877-2f5c9f5df5bc	\N	376ab6e7-f7ca-4cb0-99bd-83e09ad15d8e	\N	hitl_supervisor_agent	PO Review Required — WA-32268EF0	Moderate confidence (45.0%) — flagging for optional review	45.00	[{"source": "hitl_decision", "message": "Confidence score (45%) is below the auto-approval threshold (60%)", "severity": "medium"}]	soft_review	\N	{"packing_list": {"pl_date": "2024-09-16", "summary": {"total_packages": 430, "total_volume_cbm": 51.304, "total_net_weight_kg": 8580.0, "total_gross_weight_kg": 9193.0}, "packages": [{"hs_code": "1006.30.10", "width_cm": 50, "height_cm": 30, "length_cm": 100, "pkg_number": 1, "volume_cbm": 0.15, "description": "Basmati Rice – Grade A Extra Long Grain (1121 Variety, Aged 2 Years, Sortex Cleaned)", "packing_type": "bag", "net_weight_kg": 20.0, "gross_weight_kg": 21.5, "marks_and_numbers": "Product Name, Net/Gross Wt, Batch No., MFG Date", "number_of_packages": 100, "quantity_per_package": 20}, {"hs_code": "1006.30.10", "width_cm": 50, "height_cm": 30, "length_cm": 100, "pkg_number": 2, "volume_cbm": 0.12, "description": "Basmati Rice – Grade B Long Grain (Pusa 1121, Non-Aged)", "packing_type": "bag", "net_weight_kg": 20.0, "gross_weight_kg": 21.5, "marks_and_numbers": "Product Name, Net/Gross Wt, Batch No., MFG Date", "number_of_packages": 80, "quantity_per_package": 20}, {"hs_code": "1006.40.00", "width_cm": 40, "height_cm": 20, "length_cm": 80, "pkg_number": 3, "volume_cbm": 0.064, "description": "Broken Basmati Rice (5% Brokens)", "packing_type": "bag", "net_weight_kg": 10.0, "gross_weight_kg": 11.0, "marks_and_numbers": "Product Name, Net/Gross Wt, Batch No., MFG Date", "number_of_packages": 50, "quantity_per_package": 10}, {"hs_code": "1514.19.00", "width_cm": 20, "height_cm": 20, "length_cm": 30, "pkg_number": 4, "volume_cbm": 0.012, "description": "Rice Bran Oil – Refined (Edible Grade, 15 kg Tins) Certification: FSSAI & Halal", "packing_type": "tin", "net_weight_kg": 15.0, "gross_weight_kg": 16.5, "marks_and_numbers": "Product Name, Net/Gross Wt, Batch No., MFG Date", "number_of_packages": 200, "quantity_per_package": 1}], "pl_number": "PL001", "_confidence": 60.0, "special_flags": {"fragile": false, "dg_cargo": false, "ispm15_required": false, "refrigeration_required": false}, "_missing_fields": [{"field": "exact dimensions of each package", "blocking": false, "question": "Can you provide the exact dimensions of each package?"}, {"field": "weight of each package", "blocking": false, "question": "Can you provide the weight of each package?"}], "invoice_reference": "INV001"}, "commercial_invoice": {"gstin": "[GSTIN REQUIRED]", "items": [{"unit": "MT", "sl_no": 1, "total": 0.0, "hs_code": "1006.30.10", "quantity": 0.0, "unit_price": 0.0, "description": "Basmati Rice – Grade A Extra Long Grain (1121 Variety, Aged 2 Years, Sortex Cleaned)", "net_weight_kg": 0.0, "gross_weight_kg": 0.0, "country_of_origin": "India"}, {"unit": "MT", "sl_no": 2, "total": 0.0, "hs_code": "1006.30.10", "quantity": 0.0, "unit_price": 0.0, "description": "Basmati Rice – Grade B Long Grain (Pusa 1121, Non-Aged)", "net_weight_kg": 0.0, "gross_weight_kg": 0.0, "country_of_origin": "India"}, {"unit": "MT", "sl_no": 3, "total": 0.0, "hs_code": "1006.40.00", "quantity": 0.0, "unit_price": 0.0, "description": "Broken Basmati Rice (5% Brokens)", "net_weight_kg": 0.0, "gross_weight_kg": 0.0, "country_of_origin": "India"}, {"unit": "TINS", "sl_no": 4, "total": 0.0, "hs_code": "1514.19.00", "quantity": 0.0, "unit_price": 0.0, "description": "Rice Bran Oil – Refined (Edible Grade, 15 kg Tins) Certification: FSSAI & Halal", "net_weight_kg": 0.0, "gross_weight_kg": 0.0, "country_of_origin": "India"}], "freight": 0.0, "currency": "USD", "exporter": {"pan": "[PAN REQUIRED]", "city": "[CITY REQUIRED]", "name": "[EXPORTER NAME REQUIRED]", "gstin": "[GSTIN REQUIRED]", "ad_code": "[AD CODE REQUIRED]", "country": "India", "iec_code": "[IEC NUMBER REQUIRED]", "address_line1": "[ADDRESS LINE 1 REQUIRED]", "address_line2": "[ADDRESS LINE 2 REQUIRED]"}, "importer": {"name": "AL NOOR FOODSTUFF TRADING LLC", "address": "P.O. Box 47823, Deira, Dubai, United Arab Emirates", "country": "United Arab Emirates", "vat_trn": "100358291200003"}, "subtotal": 0.0, "incoterms": "CIF – Jebel Ali Port, Dubai (UAE)", "insurance": 0.0, "_confidence": 45.0, "declaration": "We declare that this invoice shows the actual price of goods described.", "grand_total": 0.0, "igst_amount": 0.0, "bank_details": {"iban": null, "ifsc": "[IFSC REQUIRED]", "branch": "[BRANCH REQUIRED]", "bank_name": "[BANK NAME REQUIRED]", "swift_code": "[SWIFT CODE REQUIRED]", "account_number": "[ACCOUNT NUMBER REQUIRED]"}, "invoice_date": "2024-05-22", "lc_reference": null, "pre_carriage": "[PRE-CARRIAGE REQUIRED]", "exchange_rate": 0.0, "other_charges": 0.0, "payment_terms": "Irrevocable LC at Sight (SWIFT MT700)", "vessel_flight": null, "inr_equivalent": 0.0, "invoice_number": "EXP/2024/001", "_missing_fields": [{"field": "lc_number", "blocking": true, "question": "Please provide the LC Number as per SWIFT MT700."}, {"field": "exporter_details", "blocking": true, "question": "Please provide full exporter address, IEC, GSTIN, and AD Code."}, {"field": "quantity_and_price", "blocking": true, "question": "Please provide quantities and unit prices for all line items."}], "amount_in_words": "ZERO USD ONLY", "lut_bond_number": "[LUT/BOND REFERENCE REQUIRED]", "port_of_loading": "[PORT OF LOADING REQUIRED]", "port_of_discharge": "Jebel Ali Port, Dubai", "_lc_compliance_flags": ["LC Number missing", "LC Expiry Date missing", "LC Amount missing"], "authorized_signatory": "[NAME/DESIGNATION REQUIRED]", "country_of_final_destination": "United Arab Emirates"}}	pending	00000000-0000-0000-0000-000000000002	\N	\N	\N	2026-05-30 17:48:30.529028+00	2026-05-30 13:48:30.536156+00
bb3d4c90-a4f2-4ffd-9ce7-2f3762d177db	00000000-0000-0000-0000-000000000001	e6d77cda-4d26-494c-af9c-54cd6a400bfa	\N	24889a31-2b0f-48db-8fd4-f3630e78b99c	\N	hitl_supervisor_agent	PO Review Required — WA-E6D77CDA	High-severity flags: ['Automated compliance checks failed/timed out. Manual verification of HS codes and regulations required.']	45.00	[{"source": "hs_validation", "message": "Automated compliance checks failed/timed out. Manual verification of HS codes and regulations required.", "severity": "high"}, {"source": "hitl_decision", "message": "Confidence score (45%) is below the auto-approval threshold (60%)", "severity": "medium"}]	require_human	\N	{"packing_list": {"_draft": true, "pl_number": "PL-E6D77CDA", "_confidence": 60.0, "total_packages": 1, "total_volume_cbm": 0, "total_net_weight_kg": 0, "total_gross_weight_kg": 0}, "commercial_invoice": {"items": [{"qty": 130.0, "unit": "KG", "description": "Rice"}], "_draft": true, "currency": "USD", "importer": {"name": null}, "incoterms": "CIF", "_confidence": 60.0, "declaration": "Draft — pending review.", "grand_total": 30000.0, "bank_details": {"name": "State Bank of India", "swift": "SBININBB"}, "invoice_date": "2026-05-26", "payment_terms": "LC", "invoice_number": "DRAFT-E6D77CDA", "port_of_discharge": "Nhava Sheva"}}	approved	00000000-0000-0000-0000-000000000002	00000000-0000-0000-0000-000000000002	2026-05-26 14:03:48.433058+00	Actioned via Agent Hub MVP	2026-05-26 18:02:50.32949+00	2026-05-26 14:02:50.342936+00
e13247cf-5b22-4f68-9964-321257cc031f	00000000-0000-0000-0000-000000000001	4a362369-50d6-475e-8a2c-4604360c9518	\N	e65c2467-fec8-4786-af6e-76caae76302e	\N	hitl_supervisor_agent	PO Review Required — WA-4A362369	High-severity flags: ['Automated compliance checks failed/timed out. Manual verification of HS codes and regulations required.']	45.00	[{"source": "hs_validation", "message": "Automated compliance checks failed/timed out. Manual verification of HS codes and regulations required.", "severity": "high"}, {"source": "hitl_decision", "message": "Confidence score (45%) is below the auto-approval threshold (60%)", "severity": "medium"}]	require_human	\N	{"packing_list": {"_draft": true, "pl_number": "PL-4A362369", "_confidence": 60.0, "total_packages": 1, "total_volume_cbm": 0, "total_net_weight_kg": 0, "total_gross_weight_kg": 0}, "commercial_invoice": {"items": [{"qty": 130.0, "unit": "KG", "description": "Rice"}], "_draft": true, "currency": "USD", "importer": {"name": null}, "incoterms": "CIF", "_confidence": 60.0, "declaration": "Draft — pending review.", "grand_total": 30000.0, "bank_details": {"name": "State Bank of India", "swift": "SBININBB"}, "invoice_date": "2026-05-26", "payment_terms": "LC", "invoice_number": "DRAFT-4A362369", "port_of_discharge": "Nhava Sheva"}}	approved	00000000-0000-0000-0000-000000000002	00000000-0000-0000-0000-000000000002	2026-05-26 14:03:49.679516+00	Actioned via Agent Hub MVP	2026-05-26 17:56:07.772009+00	2026-05-26 13:56:07.773133+00
8bc8db2c-2b63-4303-bd79-c33c9a8556aa	00000000-0000-0000-0000-000000000001	2a088130-3a97-49d7-aa89-46f10ad5712d	\N	88fdf1d0-9b49-4c79-90db-de508e243c39	\N	hitl_supervisor_agent	PO Review Required — WA-2A088130	High-severity flags: ['Automated compliance checks failed/timed out. Manual verification of HS codes and regulations required.']	45.00	[{"source": "hs_validation", "message": "Automated compliance checks failed/timed out. Manual verification of HS codes and regulations required.", "severity": "high"}, {"source": "hitl_decision", "message": "Confidence score (45%) is below the auto-approval threshold (60%)", "severity": "medium"}]	require_human	\N	{"packing_list": {"_draft": true, "pl_number": "PL-2A088130", "_confidence": 60.0, "total_packages": 1, "total_volume_cbm": 0, "total_net_weight_kg": 0, "total_gross_weight_kg": 0}, "commercial_invoice": {"items": [{"qty": 25.0, "unit": "KG", "description": "Basmati Rice"}], "_draft": true, "currency": "USD", "importer": {"name": "shipment date"}, "incoterms": "CIF", "_confidence": 60.0, "declaration": "Draft — pending review.", "grand_total": 0.0, "bank_details": {"name": "State Bank of India", "swift": "SBININBB"}, "invoice_date": "2026-05-26", "payment_terms": "LC", "invoice_number": "DRAFT-2A088130", "port_of_discharge": "Jebel Ali Port"}}	approved	00000000-0000-0000-0000-000000000002	00000000-0000-0000-0000-000000000002	2026-05-26 14:03:46.459534+00	Actioned via Agent Hub MVP	2026-05-26 18:03:31.332053+00	2026-05-26 14:03:31.34543+00
\.


--
-- Data for Name: audit_log; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.audit_log (id, org_id, actor_type, actor_id, action, entity_type, entity_id, old_value, new_value, metadata, ip_address, user_agent, created_at) FROM stdin;
1	00000000-0000-0000-0000-000000000001	user	00000000-0000-0000-0000-000000000002	approval.reject	approval_request	a18fd8fd-8363-445f-85bb-f63e35397996	{"status": "pending"}	{"note": "Actioned via Agent Hub MVP", "status": "rejected"}	{"field_overrides": {}}	\N	\N	2026-05-26 13:31:13.594508+00
2	00000000-0000-0000-0000-000000000001	user	00000000-0000-0000-0000-000000000002	approval.approve	approval_request	8bc8db2c-2b63-4303-bd79-c33c9a8556aa	{"status": "pending"}	{"note": "Actioned via Agent Hub MVP", "status": "approved"}	{"field_overrides": {}}	\N	\N	2026-05-26 14:03:46.456328+00
3	00000000-0000-0000-0000-000000000001	user	00000000-0000-0000-0000-000000000002	approval.approve	approval_request	bb3d4c90-a4f2-4ffd-9ce7-2f3762d177db	{"status": "pending"}	{"note": "Actioned via Agent Hub MVP", "status": "approved"}	{"field_overrides": {}}	\N	\N	2026-05-26 14:03:48.430911+00
4	00000000-0000-0000-0000-000000000001	user	00000000-0000-0000-0000-000000000002	approval.approve	approval_request	e13247cf-5b22-4f68-9964-321257cc031f	{"status": "pending"}	{"note": "Actioned via Agent Hub MVP", "status": "approved"}	{"field_overrides": {}}	\N	\N	2026-05-26 14:03:49.677451+00
5	00000000-0000-0000-0000-000000000001	user	00000000-0000-0000-0000-000000000002	approval.reject	approval_request	121ae964-da68-457c-ba8d-13db1fff0063	{"status": "pending"}	{"note": "Actioned via Agent Hub MVP", "status": "rejected"}	{"field_overrides": {}}	\N	\N	2026-05-26 14:18:00.91114+00
6	00000000-0000-0000-0000-000000000001	user	00000000-0000-0000-0000-000000000002	approval.reject	approval_request	d81ebfe5-fda7-4b44-805f-b89d3084686f	{"status": "pending"}	{"note": "Actioned via Agent Hub MVP", "status": "rejected"}	{"field_overrides": {}}	\N	\N	2026-05-26 14:18:02.407301+00
7	00000000-0000-0000-0000-000000000001	user	00000000-0000-0000-0000-000000000002	approval.reject	approval_request	5e513fe4-d830-47e4-8e5f-7c7d1236abff	{"status": "pending"}	{"note": "Actioned via Agent Hub MVP", "status": "rejected"}	{"field_overrides": {}}	\N	\N	2026-05-26 14:18:03.113654+00
8	00000000-0000-0000-0000-000000000001	user	00000000-0000-0000-0000-000000000002	approval.reject	approval_request	595c2e0b-f85f-4acd-93bc-81b21c2e964a	{"status": "pending"}	{"note": "Actioned via Agent Hub MVP", "status": "rejected"}	{"field_overrides": {}}	\N	\N	2026-05-26 14:18:04.641834+00
9	00000000-0000-0000-0000-000000000001	user	00000000-0000-0000-0000-000000000002	approval.reject	approval_request	c313582a-7fcb-42a6-aeff-a547787e2f2c	{"status": "pending"}	{"note": "Actioned via Agent Hub MVP", "status": "rejected"}	{"field_overrides": {}}	\N	\N	2026-05-26 14:19:05.570854+00
10	00000000-0000-0000-0000-000000000001	user	00000000-0000-0000-0000-000000000002	approval.reject	approval_request	e20eb7ab-d043-406e-8a6d-b795b15c9bf0	{"status": "pending"}	{"note": "Actioned via Agent Hub MVP", "status": "rejected"}	{"field_overrides": {}}	\N	\N	2026-05-26 14:20:32.324503+00
11	00000000-0000-0000-0000-000000000001	user	00000000-0000-0000-0000-000000000002	approval.reject	approval_request	6234166c-65b5-4782-bcc0-d324e4ba6911	{"status": "pending"}	{"note": "Actioned via Agent Hub MVP", "status": "rejected"}	{"field_overrides": {}}	\N	\N	2026-05-26 14:23:12.040858+00
12	00000000-0000-0000-0000-000000000001	user	00000000-0000-0000-0000-000000000002	approval.reject	approval_request	be76b3ec-91cd-47b3-aa11-1c3a4428be13	{"status": "pending"}	{"note": "Actioned via Agent Hub MVP", "status": "rejected"}	{"field_overrides": {}}	\N	\N	2026-05-26 14:26:34.085908+00
13	00000000-0000-0000-0000-000000000001	user	00000000-0000-0000-0000-000000000002	approval.approve	approval_request	72f16bce-ff13-41f2-ac15-1f434677d601	{"status": "pending"}	{"note": "Actioned via Agent Hub MVP", "status": "approved"}	{"field_overrides": {}}	\N	\N	2026-05-26 14:38:51.011372+00
14	00000000-0000-0000-0000-000000000001	user	00000000-0000-0000-0000-000000000002	approval.reject	approval_request	65ebf344-b601-4ee4-abcc-6e7846b7d26f	{"status": "pending"}	{"note": "Actioned via Agent Hub MVP", "status": "rejected"}	{"field_overrides": {}}	\N	\N	2026-05-27 13:56:20.671684+00
15	00000000-0000-0000-0000-000000000001	user	00000000-0000-0000-0000-000000000002	approval.reject	approval_request	fbebb122-5a3f-478f-b339-478b04650af8	{"status": "pending"}	{"note": "Actioned via Agent Hub MVP", "status": "rejected"}	{"field_overrides": {}}	\N	\N	2026-05-27 13:56:22.629753+00
16	00000000-0000-0000-0000-000000000001	user	00000000-0000-0000-0000-000000000002	approval.reject	approval_request	2cac43dc-1ebc-48ec-82d7-8e0e72dd3bf0	{"status": "pending"}	{"note": "Actioned via Agent Hub MVP", "status": "rejected"}	{"field_overrides": {}}	\N	\N	2026-05-27 13:56:23.272914+00
17	00000000-0000-0000-0000-000000000001	user	00000000-0000-0000-0000-000000000002	approval.reject	approval_request	403b6e3c-ac88-4b50-8a7d-6eb415253151	{"status": "pending"}	{"note": "Actioned via Agent Hub MVP", "status": "rejected"}	{"field_overrides": {}}	\N	\N	2026-05-27 13:56:24.530299+00
18	5359c3a9-2913-48b8-888c-00fbfd84682f	user	00abb788-21e2-4703-807c-d6e93e04a2c9	approval.reject	approval_request	d1b7f3ad-f929-4b2e-9188-bcb1aa5a19a0	{"status": "pending"}	{"note": "Actioned via Agent Hub MVP", "status": "rejected"}	{"field_overrides": {}}	\N	\N	2026-05-29 12:51:53.263231+00
\.


--
-- Data for Name: contacts; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.contacts (id, org_id, type, name, country, currency, payment_terms, whatsapp, email, address, bank_details, custom_fields, ai_notes, preferred_doc_format, avg_order_value, risk_score, created_at, updated_at) FROM stdin;
a1000000-0000-0000-0000-000000000001	00000000-0000-0000-0000-000000000001	buyer	Al Noor Foodstuff Trading LLC	AE	USD	LC	+971501234567	procurement@alnoorfoods.ae	{"vat": "100358291200003", "city": "Deira, Dubai", "line1": "P.O. Box 47823", "country": "UAE"}	\N	{}	\N	\N	\N	15	2026-05-23 04:41:50.068651+00	2026-05-23 04:41:50.068651+00
a2000000-0000-0000-0000-000000000001	00000000-0000-0000-0000-000000000001	buyer	Gulf Fresh General Trading	AE	USD	TT	+971509876543	orders@gulffresh.ae	{"city": "Abu Dhabi", "line1": "Shop 12, Al Barsha Souk", "country": "UAE"}	\N	{}	\N	\N	\N	25	2026-05-23 04:41:50.068651+00	2026-05-23 04:41:50.068651+00
a3000000-0000-0000-0000-000000000001	00000000-0000-0000-0000-000000000001	buyer	Saudi Grain Company	SA	SAR	LC	+966501234567	imports@saudigrain.com.sa	{"city": "Riyadh", "line1": "King Fahd Road", "country": "Saudi Arabia"}	\N	{}	\N	\N	\N	10	2026-05-23 04:41:50.068651+00	2026-05-23 04:41:50.068651+00
d32d64f3-0d05-4748-99bb-6fce4bc4508c	00000000-0000-0000-0000-000000000001	buyer	Dhiraj Group	AE	USD	LC	\N	\N	\N	\N	{}	\N	\N	\N	\N	2026-05-23 06:23:32.699861+00	2026-05-23 06:23:32.699861+00
b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11	a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11	buyer	Global Imports LLC	US	USD	LC 30 Days	\N	purchasing@globalimports.demo	\N	\N	{}	\N	\N	\N	\N	2026-05-23 07:17:29.023665+00	2026-05-23 07:17:29.023665+00
32ba496a-56cd-4a2d-b27f-b911dbe6b098	00000000-0000-0000-0000-000000000001	buyer	Dhiraj Group	AE	USD	LC	\N	\N	\N	\N	{}	\N	\N	\N	\N	2026-05-23 10:10:09.51232+00	2026-05-23 10:10:09.51232+00
cd8686c4-4b6b-4f35-8edc-0491ba2b488e	00000000-0000-0000-0000-000000000001	buyer	Dhiraj Group	AE	USD	Letter of Credit (LC)	\N	\N	\N	\N	{}	\N	\N	\N	\N	2026-05-23 10:20:32.01494+00	2026-05-23 10:20:32.01494+00
b5c086c7-1a70-4da4-b59c-c1b780abcd08	00000000-0000-0000-0000-000000000001	buyer	Dhiraj Group	AE	USD	Letter of Credit (LC)	\N	\N	\N	\N	{}	\N	\N	\N	\N	2026-05-23 10:22:49.445456+00	2026-05-23 10:22:49.445456+00
67aad923-c684-40d6-9da3-8eaacff80698	00000000-0000-0000-0000-000000000001	buyer	Dhiraj Group	AE	USD	Letter of Credit (LC)	\N	\N	\N	\N	{}	\N	\N	\N	\N	2026-05-23 10:26:02.794794+00	2026-05-23 10:26:02.794794+00
8777e5b8-4e25-46df-9ee7-63de34a0348f	00000000-0000-0000-0000-000000000001	buyer	Dhiraj Group	AE	USD	LC	917893273022	\N	\N	\N	{}	\N	\N	\N	\N	2026-05-23 10:44:15.599647+00	2026-05-23 10:44:15.599647+00
8a862ca3-882a-4d8b-ae03-46f31399e799	00000000-0000-0000-0000-000000000001	buyer	DHIRAJ GROUP	AE	USD	Letter of Credit (LC)	\N	\N	\N	\N	{}	\N	\N	\N	\N	2026-05-23 10:52:55.691481+00	2026-05-23 10:52:55.691481+00
039dcf28-d3e9-417d-bab7-d29411a7ab2c	00000000-0000-0000-0000-000000000001	buyer	Dhiraj Group	AE	USD	LC	917893273022	\N	\N	\N	{}	\N	\N	\N	\N	2026-05-23 10:59:39.727235+00	2026-05-23 10:59:39.727235+00
f6e94baf-ee72-4a62-8588-0a523be17d13	00000000-0000-0000-0000-000000000001	buyer	Dhiraj Group	AE	USD	LC	917893273022	\N	\N	\N	{}	\N	\N	\N	\N	2026-05-23 11:33:19.358566+00	2026-05-23 11:33:19.358566+00
fab4633f-fe79-4fcb-9934-189f9153b732	00000000-0000-0000-0000-000000000001	buyer	Dhiraj Group	AE	USD	Letter of Credit (LC)	\N	\N	\N	\N	{}	\N	\N	\N	\N	2026-05-23 14:36:38.593467+00	2026-05-23 14:36:38.593467+00
dbbccfa1-84ab-4d68-9953-5c93daea823c	00000000-0000-0000-0000-000000000001	buyer	Dhiraj Group	AE	USD	Letter of Credit (LC)	\N	\N	\N	\N	{}	\N	\N	\N	\N	2026-05-23 14:49:04.354959+00	2026-05-23 14:49:04.354959+00
597541ba-77b1-4706-9f06-2add0d8c967b	00000000-0000-0000-0000-000000000001	buyer	Dhiraj Group	AE	USD	Letter of Credit (LC)	\N	\N	\N	\N	{}	\N	\N	\N	\N	2026-05-23 15:04:22.041692+00	2026-05-23 15:04:22.041692+00
c6e82cda-5b34-454e-9082-f5c4d8eb7429	00000000-0000-0000-0000-000000000001	buyer	Dhiraj Group	AE	USD	Letter of Credit (LC)	\N	\N	\N	\N	{}	\N	\N	\N	\N	2026-05-23 15:32:26.439969+00	2026-05-23 15:32:26.439969+00
b74a832c-38b0-4c98-acfa-20aadcaf3d88	00000000-0000-0000-0000-000000000001	buyer	Dhiraj Group	AE	USD	Letter of Credit (LC)	\N	\N	\N	\N	{}	\N	\N	\N	\N	2026-05-23 15:35:43.096101+00	2026-05-23 15:35:43.096101+00
6cebd7f3-65e8-456e-a5aa-b8dfa79f9d7e	00000000-0000-0000-0000-000000000001	buyer	Dhiraj Group	AE	USD	Letter of Credit (LC)	\N	\N	\N	\N	{}	\N	\N	\N	\N	2026-05-23 15:58:06.745539+00	2026-05-23 15:58:06.745539+00
11f9c250-6982-4398-9e8f-695044a9c36d	00000000-0000-0000-0000-000000000001	buyer	Dhiraj Group	AE	USD	Letter of Credit (LC)	917893273022	\N	\N	\N	{}	\N	\N	\N	\N	2026-05-23 15:58:26.618064+00	2026-05-23 15:58:26.618064+00
f97e28f2-3315-4b1b-bcd9-2d750c1648e2	00000000-0000-0000-0000-000000000001	buyer	Dhiraj Group	AE	USD	LC	917893273022	\N	\N	\N	{}	\N	\N	\N	\N	2026-05-23 18:18:52.559935+00	2026-05-23 18:18:52.559935+00
da61bc37-8db8-4079-83ff-22fcc46fb463	00000000-0000-0000-0000-000000000001	buyer	Dhiraj Group	AE	USD	LC	917893273022	\N	\N	\N	{}	\N	\N	\N	\N	2026-05-23 18:49:52.799815+00	2026-05-23 18:49:52.799815+00
7bfd5f01-5387-43ed-b4df-ffea3d555881	00000000-0000-0000-0000-000000000001	buyer	Dhiraj Group	AE	USD	LC	917893273022	\N	\N	\N	{}	\N	\N	\N	\N	2026-05-23 22:01:42.907661+00	2026-05-23 22:01:42.907661+00
c94b7e0d-7996-4404-b850-2f07c45dc0eb	00000000-0000-0000-0000-000000000001	buyer	Dhiraj Group	AE	USD	LC	917893273022	\N	\N	\N	{}	\N	\N	\N	\N	2026-05-23 22:46:02.391138+00	2026-05-23 22:46:02.391138+00
559ca767-9ca0-4116-b1a3-0986cc81e114	00000000-0000-0000-0000-000000000001	buyer	Dhiraj Group	AE	USD	LC	917893273022	\N	\N	\N	{}	\N	\N	\N	\N	2026-05-24 01:46:38.317061+00	2026-05-24 01:46:38.317061+00
509a2de7-4020-4465-9a78-d329fb67bcdd	00000000-0000-0000-0000-000000000001	buyer	Dhiraj Group	AE	USD	LC	917893273022	\N	\N	\N	{}	\N	\N	\N	\N	2026-05-24 04:25:02.51914+00	2026-05-24 04:25:02.51914+00
7b59098e-015a-4bf4-b8eb-5676d076bc48	00000000-0000-0000-0000-000000000001	buyer	Dhiraj Group	AE	USD	LC	917893273022	\N	\N	\N	{}	\N	\N	\N	\N	2026-05-24 05:26:06.45434+00	2026-05-24 05:26:06.45434+00
c55033df-3d08-4855-95ec-d914d41dc29c	00000000-0000-0000-0000-000000000001	buyer	Dhiraj Group	AE	USD	LC	917893273022	\N	\N	\N	{}	\N	\N	\N	\N	2026-05-24 08:41:47.993232+00	2026-05-24 08:41:47.993232+00
0e6fbc91-0555-4157-a152-95321988633f	00000000-0000-0000-0000-000000000001	buyer	Dhiraj Group	AE	USD	Letter of Credit (LC)	\N	\N	\N	\N	{}	\N	\N	\N	\N	2026-05-24 13:13:53.553858+00	2026-05-24 13:13:53.553858+00
d44cc275-96fb-414d-bdcd-71aaf79279b6	00000000-0000-0000-0000-000000000001	buyer	shipment date	IN	USD	LC	917893273022	\N	\N	\N	{}	\N	\N	\N	\N	2026-05-26 12:08:07.263911+00	2026-05-26 12:08:07.263911+00
814642fc-f4c4-4d0b-9c3f-74eebf5b2c44	00000000-0000-0000-0000-000000000001	buyer	shipment date	IN	USD	LC	917893273022	\N	\N	\N	{}	\N	\N	\N	\N	2026-05-26 12:20:51.134029+00	2026-05-26 12:20:51.134029+00
d761b1ac-585b-4718-bed7-a98a9cb987ba	00000000-0000-0000-0000-000000000001	buyer	shipment date	IN	USD	LC	917893273022	\N	\N	\N	{}	\N	\N	\N	\N	2026-05-26 13:09:54.292539+00	2026-05-26 13:09:54.292539+00
f31b94e1-59c1-4ec5-bd9e-edbd9012436e	00000000-0000-0000-0000-000000000001	buyer	Unknown Buyer	IN	USD	LC	917893273022	\N	\N	\N	{}	\N	\N	\N	\N	2026-05-26 13:56:07.76311+00	2026-05-26 13:56:07.76311+00
09ca4a16-b627-44ac-8100-453ce7fba55a	00000000-0000-0000-0000-000000000001	buyer	Unknown Buyer	IN	USD	LC	\N	\N	\N	\N	{}	\N	\N	\N	\N	2026-05-26 14:02:50.327548+00	2026-05-26 14:02:50.327548+00
cf11741d-e8ba-47e5-8f78-14f7d15aeb2e	00000000-0000-0000-0000-000000000001	buyer	shipment date	IN	USD	LC	\N	\N	\N	\N	{}	\N	\N	\N	\N	2026-05-26 14:03:31.341252+00	2026-05-26 14:03:31.341252+00
4c353781-3ada-4ef4-9a4b-da3790a30b19	00000000-0000-0000-0000-000000000001	buyer	Unknown Buyer	AE	USD	LC	\N	\N	\N	\N	{}	\N	\N	\N	\N	2026-05-26 14:10:49.299246+00	2026-05-26 14:10:49.299246+00
410cbeda-1cfd-431f-aaa2-64c8f2cc9b5d	00000000-0000-0000-0000-000000000001	buyer	Unknown Buyer	AE	USD	LC	\N	\N	\N	\N	{}	\N	\N	\N	\N	2026-05-26 14:11:46.322724+00	2026-05-26 14:11:46.322724+00
607d9303-1dd5-45ee-9697-29303796ef69	00000000-0000-0000-0000-000000000001	buyer	shipment date	IN	USD	LC	\N	\N	\N	\N	{}	\N	\N	\N	\N	2026-05-26 14:12:38.62785+00	2026-05-26 14:12:38.62785+00
df66d47f-b6c4-43c1-a720-76a41af8b230	00000000-0000-0000-0000-000000000001	buyer	shipment date	IN	USD	LC	\N	\N	\N	\N	{}	\N	\N	\N	\N	2026-05-26 14:17:15.338265+00	2026-05-26 14:17:15.338265+00
21fb391f-8396-4d4d-8215-5391de91afa4	00000000-0000-0000-0000-000000000001	buyer	shipment date	IN	USD	LC	\N	\N	\N	\N	{}	\N	\N	\N	\N	2026-05-26 14:18:57.68504+00	2026-05-26 14:18:57.68504+00
203565af-55da-42da-ba48-e676d0f5c902	00000000-0000-0000-0000-000000000001	buyer	shipment date	IN	USD	LC	\N	\N	\N	\N	{}	\N	\N	\N	\N	2026-05-26 14:19:17.236862+00	2026-05-26 14:19:17.236862+00
5285d8e8-c354-4f05-b27e-b5ed779b3424	00000000-0000-0000-0000-000000000001	buyer	shipment date	IN	USD	LC	\N	\N	\N	\N	{}	\N	\N	\N	\N	2026-05-26 14:22:39.624763+00	2026-05-26 14:22:39.624763+00
e206ee52-05e4-44f6-bed5-501172701af7	00000000-0000-0000-0000-000000000001	buyer	Unknown Buyer	AE	USD	LC	\N	\N	\N	\N	{}	\N	\N	\N	\N	2026-05-26 14:26:24.981892+00	2026-05-26 14:26:24.981892+00
57863633-f2fd-460e-80be-fbe8d1bd4a2b	00000000-0000-0000-0000-000000000001	buyer	shipment date	IN	USD	LC	\N	\N	\N	\N	{}	\N	\N	\N	\N	2026-05-26 14:38:37.851945+00	2026-05-26 14:38:37.851945+00
411e1cc1-b9d1-458c-baee-90da924cce16	00000000-0000-0000-0000-000000000001	buyer	Unknown Buyer	IN	USD	LC	917893273022	\N	\N	\N	{}	\N	\N	\N	\N	2026-05-27 03:21:07.816834+00	2026-05-27 03:21:07.816834+00
229b7106-3743-4b74-a2b4-6a91b23db4db	00000000-0000-0000-0000-000000000001	buyer	Unknown Buyer	IN	USD	LC	917893273022	\N	\N	\N	{}	\N	\N	\N	\N	2026-05-27 04:48:23.472191+00	2026-05-27 04:48:23.472191+00
1b2aa3c3-df1a-4e80-808a-7c5484a58308	00000000-0000-0000-0000-000000000001	buyer	Unknown Buyer	IN	USD	LC	917893273022	\N	\N	\N	{}	\N	\N	\N	\N	2026-05-27 04:49:32.770264+00	2026-05-27 04:49:32.770264+00
7c0de00f-66c5-4718-a17b-bd656905f49e	00000000-0000-0000-0000-000000000001	buyer	AGRO EXPORTS INDIA PVT. LTD.	IN	USD	Letter of Credit (LC)	917893273022	\N	\N	\N	{}	\N	\N	\N	\N	2026-05-27 06:29:11.767844+00	2026-05-27 06:29:11.767844+00
080f7840-73dd-4269-8afb-76756f23eb23	00000000-0000-0000-0000-000000000001	buyer	DHIRAJ GROUP	AE	USD	Letter of Credit	917893273022	\N	\N	\N	{}	\N	\N	\N	\N	2026-05-29 06:07:40.991961+00	2026-05-29 06:07:40.991961+00
b5166f9a-6501-4ecd-90ee-b2b6d9b066b9	5359c3a9-2913-48b8-888c-00fbfd84682f	buyer	AL NOOR FOODSTUFF TRADING LLC	AE	USD	Irrevocable LC at Sight (SWIFT MT700)	\N	\N	\N	\N	{}	\N	\N	\N	\N	2026-05-29 12:51:40.829358+00	2026-05-29 12:51:40.829358+00
ddda41f1-a7fb-4470-9cef-174d7cb99c6f	841689d4-2d6a-4391-b453-930e6fbb35a5	buyer	DHIRAJ GROUP	AE	USD	Letter of Credit	\N	\N	\N	\N	{}	\N	\N	\N	\N	2026-05-30 01:37:58.792417+00	2026-05-30 01:37:58.792417+00
5599f9eb-4f95-4563-a159-e2713571859d	005d0831-36c7-4d44-bb52-6d9a13bacb4d	buyer	AL NOOR FOODSTUFF TRADING LLC	AE	USD	Irrevocable LC at Sight (SWIFT MT700)	\N	\N	\N	\N	{}	\N	\N	\N	\N	2026-05-30 13:48:30.505378+00	2026-05-30 13:48:30.505378+00
381591d5-6439-4ac4-8be9-e2a16d556918	07ab628b-6aa2-47e9-9893-fbdd583a7cba	buyer	AL NOOR FOODSTUFF TRADING LLC	AE	USD	Irrevocable LC at Sight (SWIFT MT700)	\N	\N	\N	\N	{}	\N	\N	\N	\N	2026-06-04 11:24:36.026785+00	2026-06-04 11:24:36.026785+00
\.


--
-- Data for Name: country_trade_rules; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.country_trade_rules (id, from_country, to_country, hs_code_prefix, rule_type, rule_value, source, effective_from, effective_to, updated_at) FROM stdin;
\.


--
-- Data for Name: documents; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.documents (id, org_id, order_id, doc_type, reference_number, status, version, parent_version_id, storage_path, file_size_bytes, mime_type, checksum, generated_by, ai_confidence, generation_prompt_id, extracted_data, reviewed_by, reviewed_at, review_notes, created_at, updated_at) FROM stdin;
d1000000-0000-0000-0000-000000000001	00000000-0000-0000-0000-000000000001	a1000000-0000-0000-0000-000000000001	commercial_invoice	INV-AEIPL-2026-0501	approved	1	\N	\N	184320	application/pdf	\N	doc_generation_agent	95.00	\N	{"buyer": "Al Noor Foodstuff Trading LLC", "items": 1, "currency": "USD", "grand_total": 23185.00, "invoice_number": "INV-AEIPL-2026-0501"}	\N	\N	\N	2026-05-21 05:41:50.068651+00	2026-05-21 06:41:50.068651+00
d1000000-0000-0000-0000-000000000002	00000000-0000-0000-0000-000000000001	a1000000-0000-0000-0000-000000000001	packing_list	PL-AEIPL-2026-0501	approved	1	\N	\N	92160	application/pdf	\N	doc_generation_agent	95.00	\N	{"pl_number": "PL-AEIPL-2026-0501", "total_packages": 400, "total_net_weight_kg": 10000}	\N	\N	\N	2026-05-21 05:41:50.068651+00	2026-05-21 06:41:50.068651+00
d1000000-0000-0000-0000-000000000003	00000000-0000-0000-0000-000000000001	a1000000-0000-0000-0000-000000000001	certificate_of_origin	COO-AEIPL-2026-0501	approved	1	\N	\N	61440	application/pdf	\N	doc_generation_agent	88.00	\N	{"origin": "India", "certificate_number": "COO-AEIPL-2026-0501"}	\N	\N	\N	2026-05-21 06:41:50.068651+00	2026-05-21 07:41:50.068651+00
d1000000-0000-0000-0000-000000000004	00000000-0000-0000-0000-000000000001	a1000000-0000-0000-0000-000000000002	commercial_invoice	INV-AEIPL-2026-0502	pending_review	1	\N	\N	176128	application/pdf	\N	doc_generation_agent	72.00	\N	{"buyer": "Gulf Fresh General Trading", "currency": "USD", "grand_total": 14700.00, "invoice_number": "INV-AEIPL-2026-0502"}	\N	\N	\N	2026-05-23 01:56:50.068651+00	2026-05-23 01:56:50.068651+00
d1000000-0000-0000-0000-000000000005	00000000-0000-0000-0000-000000000001	a1000000-0000-0000-0000-000000000002	packing_list	PL-AEIPL-2026-0502	pending_review	1	\N	\N	86016	application/pdf	\N	doc_generation_agent	72.00	\N	{"pl_number": "PL-AEIPL-2026-0502", "total_packages": 100, "total_net_weight_kg": 5000}	\N	\N	\N	2026-05-23 01:57:50.068651+00	2026-05-23 01:57:50.068651+00
d1000000-0000-0000-0000-000000000006	00000000-0000-0000-0000-000000000001	a1000000-0000-0000-0000-000000000003	commercial_invoice	DRAFT-INV-2026-0312	draft	1	\N	\N	0	application/pdf	\N	doc_generation_agent	91.00	\N	{"buyer": "Saudi Grain Company", "currency": "USD", "grand_total": 58000.00, "invoice_number": "DRAFT-INV-2026-0312"}	\N	\N	\N	2026-05-23 04:26:50.068651+00	2026-05-23 04:26:50.068651+00
d1000000-0000-0000-0000-000000000007	00000000-0000-0000-0000-000000000001	a1000000-0000-0000-0000-000000000004	commercial_invoice	INV-AEIPL-2026-0498	sent	1	\N	\N	163840	application/pdf	\N	doc_generation_agent	89.00	\N	{"buyer": "Al Noor Foodstuff Trading LLC", "currency": "USD", "grand_total": 8700.00, "invoice_number": "INV-AEIPL-2026-0498"}	\N	\N	\N	2026-05-18 06:41:50.068651+00	2026-05-18 07:41:50.068651+00
d1000000-0000-0000-0000-000000000008	00000000-0000-0000-0000-000000000001	a1000000-0000-0000-0000-000000000004	packing_list	PL-AEIPL-2026-0498	sent	1	\N	\N	81920	application/pdf	\N	doc_generation_agent	89.00	\N	{"pl_number": "PL-AEIPL-2026-0498", "total_packages": 134, "total_net_weight_kg": 2000}	\N	\N	\N	2026-05-18 06:41:50.068651+00	2026-05-18 07:41:50.068651+00
d1000000-0000-0000-0000-000000000009	00000000-0000-0000-0000-000000000001	a1000000-0000-0000-0000-000000000004	bill_of_lading	BL-MSCU-2026-748291	sent	1	\N	\N	122880	application/pdf	\N	logistics_agent	85.00	\N	{"eta": "2026-05-22", "etd": "2026-05-18", "vessel": "MSC AFRICA", "voyage": "2604E", "bl_number": "MSCU2026748291"}	\N	\N	\N	2026-05-18 10:41:50.068651+00	2026-05-18 10:41:50.068651+00
\.


--
-- Data for Name: hitl_corrections; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.hitl_corrections (id, org_id, workflow_id, order_id, buyer_key, field_name, wrong_value, correct_value, correction_source, corrected_by, created_at) FROM stdin;
\.


--
-- Data for Name: hs_codes; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.hs_codes (id, code, description, chapter, parent_code, notes, embedding, updated_at) FROM stdin;
\.


--
-- Data for Name: logistics_rate_cards; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.logistics_rate_cards (id, vendor_id, charge_type, unit_type, rate, minimum_charge, hazardous_rules, gst_applicable, effective_date, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: logistics_vendors; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.logistics_vendors (id, org_id, name, country, supported_ports, contact_info, services, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: mcp_api_keys; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.mcp_api_keys (id, org_id, key_hash, key_prefix, environment, is_active, last_used_at, created_at) FROM stdin;
\.


--
-- Data for Name: mcp_billing; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.mcp_billing (id, org_id, period_start, period_end, plan, calls_used, calls_limit, cost_usd, is_paid, created_at) FROM stdin;
\.


--
-- Data for Name: mcp_usage_log; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.mcp_usage_log (id, org_id, service, action, request_ms, tokens_used, cost_usd, status, created_at) FROM stdin;
\.


--
-- Data for Name: messages; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.messages (id, org_id, order_id, contact_id, channel, direction, from_address, to_address, subject, body, body_lang, body_translated, attachments, intent, extracted_data, ai_processed, status, external_id, created_at) FROM stdin;
\.


--
-- Data for Name: order_items; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.order_items (id, order_id, product_id, description, hs_code, quantity, unit, unit_price, discount_pct) FROM stdin;
596be9d4-e631-4b19-939d-9c657e5a6ed8	a1000000-0000-0000-0000-000000000001	b1000000-0000-0000-0000-000000000001	Basmati Rice Grade A 1121	1006302000	10000.0000	KG	1.2000	0.00
b05b040d-ec2d-4c2f-8be9-91fb63040fb7	a1000000-0000-0000-0000-000000000002	b2000000-0000-0000-0000-000000000001	Basmati Rice Grade B Pusa 1121	1006302000	5000.0000	KG	0.9800	0.00
0b0060f8-6aca-4745-8eed-3f12441e1987	a1000000-0000-0000-0000-000000000003	b1000000-0000-0000-0000-000000000001	Basmati Rice Grade A 1121	1006302000	40000.0000	KG	1.2000	0.00
23fca099-4232-4288-a897-b4101cf04611	a1000000-0000-0000-0000-000000000003	b2000000-0000-0000-0000-000000000001	Basmati Rice Grade B	1006302000	10000.0000	KG	0.9800	0.00
5b8dc56d-7884-4f24-9cd2-fdf05ba9624e	a1000000-0000-0000-0000-000000000004	b3000000-0000-0000-0000-000000000001	Refined Rice Bran Oil	1514191000	2000.0000	KG	1.4500	0.00
f0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11	c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11	e0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11	Premium Cotton T-Shirts	61091000	3000.0000	PCS	15.0000	0.00
f0eebc99-9c0b-4ef8-bb6d-6bb9bd380a12	c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a12	e0eebc99-9c0b-4ef8-bb6d-6bb9bd380a12	Wireless Earbuds	85183000	277.0000	PCS	45.0000	0.00
\.


--
-- Data for Name: orders; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.orders (id, org_id, order_number, buyer_id, status, currency, total_amount, payment_terms, incoterms, port_of_loading, port_of_discharge, destination_country, po_source, po_raw_text, po_file_id, workflow_id, assigned_to, notes, created_at, updated_at) FROM stdin;
a1000000-0000-0000-0000-000000000001	00000000-0000-0000-0000-000000000001	WA-A1000001	a1000000-0000-0000-0000-000000000001	dispatched	USD	23185.00	LC	CIF	Nhava Sheva (JNPT), Mumbai	Jebel Ali Port, Dubai	AE	whatsapp	We need 1000 KG Basmati Rice Grade A, destination Dubai, CIF, USD 1.20/kg, payment by LC	\N	ef000000-0000-0000-0000-000000000001	\N	\N	2026-05-23 04:41:50.068651+00	2026-05-23 04:41:50.068651+00
a1000000-0000-0000-0000-000000000002	00000000-0000-0000-0000-000000000001	WA-A1000002	a2000000-0000-0000-0000-000000000001	awaiting_approval	USD	14700.00	TT	FOB	Nhava Sheva (JNPT), Mumbai	Abu Dhabi Port	AE	whatsapp	Need 5000 KG Basmati Rice Pusa 1121 Grade B, FOB Mumbai, USD 0.98/kg, TT payment 30 days	\N	ef000000-0000-0000-0000-000000000002	\N	\N	2026-05-23 04:41:50.068651+00	2026-05-23 04:41:50.068651+00
a1000000-0000-0000-0000-000000000004	00000000-0000-0000-0000-000000000001	WA-A1000004	a1000000-0000-0000-0000-000000000001	in_transit	USD	8700.00	TT	CIF	Nhava Sheva (JNPT), Mumbai	Jebel Ali Port, Dubai	AE	whatsapp	Need 2000 kg refined rice bran oil CIF Dubai USD 1.45/kg TT payment	\N	ef000000-0000-0000-0000-000000000004	\N	\N	2026-05-23 04:41:50.068651+00	2026-05-23 04:41:50.068651+00
d2f29e8a-f939-43ad-9156-ec46457405b8	00000000-0000-0000-0000-000000000001	WA-A90E7E81	d32d64f3-0d05-4748-99bb-6fce4bc4508c	awaiting_approval	USD	\N	LC	CIF	\N	\N	AE	portal	\N	\N	a90e7e81-2713-4731-aad7-edfe4c1ac77a	\N	\N	2026-05-23 06:23:32.715307+00	2026-05-23 06:23:32.715307+00
c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11	a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11	ORD-2026-001	b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11	in_transit	USD	45000.00	LC 30 Days	FOB	INNSA	USNYC	US	\N	\N	\N	\N	\N	\N	2026-05-23 07:17:29.800821+00	2026-05-23 07:17:29.800821+00
c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a12	a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11	ORD-2026-002	b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11	in_transit	USD	12465.00	LC 30 Days	CIF	INBOM	GBHDR	GB	\N	\N	\N	\N	\N	\N	2026-05-23 07:17:29.800821+00	2026-05-23 07:17:29.800821+00
eaae9fb7-7189-4ba2-a008-5e56f0d0b3a6	00000000-0000-0000-0000-000000000001	WA-89F714B4	67aad923-c684-40d6-9da3-8eaacff80698	awaiting_approval	USD	\N	Letter of Credit (LC)	CIF	\N	Jebel Ali Port, Dubai	AE	portal	\N	\N	89f714b4-1382-4117-be0a-2357ada57c27	\N	\N	2026-05-23 10:26:02.799277+00	2026-05-23 10:26:02.799277+00
96cdc2ac-f0df-4d19-9b07-9ac0b59eae82	00000000-0000-0000-0000-000000000001	WA-6ED40049	8777e5b8-4e25-46df-9ee7-63de34a0348f	awaiting_approval	USD	\N	LC	CIF	\N	\N	AE	whatsapp	\N	\N	6ed40049-12da-4197-be3f-e1636270446b	\N	\N	2026-05-23 10:44:15.606409+00	2026-05-23 10:44:15.606409+00
08db030b-52c2-4bf6-9ef0-55ba90735339	00000000-0000-0000-0000-000000000001	WA-B249A40D	8a862ca3-882a-4d8b-ae03-46f31399e799	documents_pending	USD	\N	Letter of Credit (LC)	CIF - Jebel Ali Port, Dubai (UAE)	\N	Jebel Ali Port, Dubai, UAE	AE	portal	\N	\N	b249a40d-537c-4b26-bb7d-d91b2d63c1da	\N	\N	2026-05-23 10:52:55.69615+00	2026-05-23 10:52:55.69615+00
e8d4f064-ccec-4bfb-b5e0-48d874894cd8	00000000-0000-0000-0000-000000000001	WA-FFBE6CC8	f6e94baf-ee72-4a62-8588-0a523be17d13	awaiting_approval	USD	\N	LC	CIF	\N	\N	AE	whatsapp	\N	\N	ffbe6cc8-a990-4036-9078-3db7ee26072b	\N	\N	2026-05-23 11:33:19.366461+00	2026-05-23 11:33:19.366461+00
cc552ddb-ec65-4cd9-b972-cfa94da3ddd9	00000000-0000-0000-0000-000000000001	WA-5CB9440F	dbbccfa1-84ab-4d68-9953-5c93daea823c	awaiting_approval	USD	\N	Letter of Credit (LC)	CIF	\N	Jebel Ali Port, Dubai	AE	portal	\N	\N	5cb9440f-5a3d-4c7e-8d3c-9c185aceed4e	\N	\N	2026-05-23 14:49:04.363447+00	2026-05-23 14:49:04.363447+00
d1829d06-4954-4ca9-bfeb-1caf946a4a41	00000000-0000-0000-0000-000000000001	WA-DD300701	597541ba-77b1-4706-9f06-2add0d8c967b	awaiting_approval	USD	\N	Letter of Credit (LC)	CIF	\N	Jebel Ali Port, Dubai	AE	portal	\N	\N	dd300701-c9ad-478e-bc6c-33623d27b9bb	\N	\N	2026-05-23 15:04:22.048875+00	2026-05-23 15:04:22.048875+00
ea835eb6-8e90-4cb2-ae2d-50dbf414787a	00000000-0000-0000-0000-000000000001	WA-3C7D209A	c6e82cda-5b34-454e-9082-f5c4d8eb7429	awaiting_approval	USD	\N	Letter of Credit (LC)	CIF	\N	Jebel Ali Port, Dubai	AE	portal	\N	\N	3c7d209a-a09b-4d0b-90d2-edd4bcecbc20	\N	\N	2026-05-23 15:32:26.449244+00	2026-05-23 15:32:26.449244+00
2c2a1e04-0887-4e31-8aed-759d5acbe823	00000000-0000-0000-0000-000000000001	WA-976E67CD	6cebd7f3-65e8-456e-a5aa-b8dfa79f9d7e	awaiting_approval	USD	\N	Letter of Credit (LC)	CIF	\N	Jebel Ali Port, Dubai	AE	portal	\N	\N	976e67cd-9269-4693-9a58-b7d1e0c2a2f7	\N	\N	2026-05-23 15:58:06.752013+00	2026-05-23 15:58:06.752013+00
4a1cf358-2549-45c4-a1e5-dab409948f7c	00000000-0000-0000-0000-000000000001	WA-6161AE6E	11f9c250-6982-4398-9e8f-695044a9c36d	documents_pending	USD	\N	Letter of Credit (LC)	CIF	\N	Jebel Ali Port, Dubai	AE	whatsapp	\N	\N	6161ae6e-d3b4-433d-941f-4cc0c5c56589	\N	\N	2026-05-23 15:58:26.621269+00	2026-05-23 15:58:26.621269+00
37a6e3ec-b1b3-4017-86c8-3c1c91a77302	00000000-0000-0000-0000-000000000001	WA-271403D6	c55033df-3d08-4855-95ec-d914d41dc29c	awaiting_approval	USD	\N	LC	CIF	\N	\N	AE	whatsapp	\N	\N	271403d6-3473-4e10-8679-5f61d39fb47d	\N	\N	2026-05-24 08:41:48.013916+00	2026-05-24 08:41:48.013916+00
e65c2467-fec8-4786-af6e-76caae76302e	00000000-0000-0000-0000-000000000001	WA-4A362369	f31b94e1-59c1-4ec5-bd9e-edbd9012436e	awaiting_approval	USD	\N	LC	CIF	\N	Nhava Sheva	IN	whatsapp	\N	\N	4a362369-50d6-475e-8a2c-4604360c9518	\N	\N	2026-05-26 13:56:07.768186+00	2026-05-26 13:56:07.768186+00
24889a31-2b0f-48db-8fd4-f3630e78b99c	00000000-0000-0000-0000-000000000001	WA-E6D77CDA	09ca4a16-b627-44ac-8100-453ce7fba55a	awaiting_approval	USD	\N	LC	CIF	\N	Nhava Sheva	IN	portal	PURCHASE ORDER\r\nSELLER (Exporter)  AGRO EXPORTS INDIA PVT. LTD. \r\n123, Nariman Point, Mumbai - 400021, Maharashtra, India \r\nIEC: AABCA1234C | GSTIN: 27AABCA1234C1Z5 \r\nContact: Ms. Priya Sharma (Director - Exports) \r\nTel: +91-22-4567-8901 | Email: priya.sharma@agroexportsindia.com \r\nBUYER (Importer)  DHIRAJ GROUP 456 Business Avenue, Business Bay, Dubai, \r\nUnited Arab Emirates\r\nTRN (VAT): 100293847563\r\nPO OVERVIEW\r\nPO Number: AEIPL/PO/2026/0542 \r\nPO Date: 15 May 2026 \r\nValid Until: 30 June 2026 \r\nIncoterms:CIF - Jebel Ali Port, Dubai \r\n(UAE)\r\nCurrency: USD (United States Dollar) \r\nLUT/Bond \r\nNumber:LUT-2026-98765\r\nSHIPMENT & PAYMENT DETAILS\r\nPort of LoadingNhava Sheva (JNPT), \r\nMumbai, IndiaPayment \r\nTermsLetter of Credit \r\n(LC)\r\nPort of \r\nDischargeJebel Ali Port, Dubai, UAE LC Number LC-987654321\r\nPre-Carriage By Road TransportLC Issuing \r\nBankEmirates NBD \r\nDubai\r\nMode of \r\nTransportOcean FreightLC Expiry \r\nDate31 December \r\n2026\r\nExpected \r\nDelivery15 November 2026 Partial \r\nShipmentNot Allowed \r\nDestination \r\nCountryUnited Arab EmiratesTranshipmen\r\ntNot Allowed \r\nORDER LINE ITEMS\r\nS\r\nr\r\n.Product \r\nDescriptionHS \r\nCodeQt\r\nyUnit \r\nPrice \r\n(USD)Total \r\nAmount \r\n(USD)Country \r\nof Origin\r\n1Dell Latitude 7420  \r\nLaptops\r\nArabic:   كمبيوترمحمول \r\n  ديللاتيتيود 7420847130\r\n1010\r\n0 \r\nPC\r\nS300.0030,000.00USA\r\nSUB-TOTAL10\r\n0 \r\nPC\r\nS30,000.00\r\nSea Freight & \r\nInsuranceIncluded \r\n(CIF)\r\nGRAND TOTALUSD \r\n30,000.00\r\nPACKING SPECIFICATIONS\r\n•Packaging Type:  Standard Export Packaging. Laptops are properly packaged and \r\nmarked for export.\r\n•Configuration: 100 Laptops packed in 10 master cartons (10 laptops per carton).\r\n•Carton Dimensions:  $50\\text{cm} \\times 40\\text{cm} \\times 30\\text{cm}$ .\r\n•Weight Metrics:  * Net Weight per Carton:  13 kg\r\n•Gross Weight per Carton:  15.5 kg\r\n•Total Net Weight:  130 kg\r\n•Total Gross Weight:  155 kg\r\n•Labelling: All cartons must be clearly labelled with product name, net/gross weight, \r\nbatch/serial numbers, and country of origin.\r\nBENEFICIARY BANK DETAILS\r\nBank Name State Bank of India, Fort Branch, Mumbai \r\nBranch Mumbai Main Branch, Fort, Mumbai \r\nAddress 400001 \r\nAccount \r\nNameAgro Exports India Pvt. Ltd. \r\nAccount No. 10234567890 \r\nIFSC Code SBIN0000300 \r\nSWIFT Code SBININBB \r\nTERMS & CONDITIONS\r\n1.Acceptance: Seller must confirm acceptance of this updated purchase order within 5 \r\nworking days. \r\n2.Documentation:  The following original documents are required for customs \r\nclearance: Signed Commercial Invoice (3 originals), Packing List, Full Set 3/3 Original \r\nBill of Lading (OBL), Certificate of Origin, and Quality/Inspection Certificates.  \r\n3.Insurance: Marine insurance is to be covered by the Seller for 110% of the CIF value \r\nunder Institute Cargo Clauses (A).  \r\n4.Governing Law:  This contract shall be governed by ICC Rules. Any disputes that \r\ncannot be settled amicably shall be resolved by arbitration in Dubai, UAE.  \r\nFOR DHIRAJ GROUP  ___________________________\r\nAuthorised Signatory  Date:\r\nFOR AGRO EXPORTS INDIA PVT. LTD. \r\nAuthorised Signatory  \r\nName: Ms. Priya Sharma \r\nDesignation: Director - Exports \r\nDate: 20th May 2026	\N	e6d77cda-4d26-494c-af9c-54cd6a400bfa	\N	\N	2026-05-26 14:02:50.331186+00	2026-05-26 14:02:50.331186+00
88fdf1d0-9b49-4c79-90db-de508e243c39	00000000-0000-0000-0000-000000000001	WA-2A088130	cf11741d-e8ba-47e5-8f78-14f7d15aeb2e	awaiting_approval	USD	\N	LC	CIF	\N	Jebel Ali Port	IN	portal	AGRO EXPORTS INDIA PVT. LTD. IEC: AABCA1234C    GSTIN: 27AABCA1234C1Z5\r\n123, Nariman Point, Mumbai - 400021, Maharashtra, India\r\nTel: +91-22-4567-8900   Email: exports@agroexportsindia.com\r\n Web: www.agroexportsindia.com\r\n \r\nPURCHASE ORDERPO Number:\r\nAEIPL/PO/2026/0542\r\nPO Date:\r\n15 May 2026\r\nValid Until:\r\n30 June 2026\r\nIncoterms:\r\nCIF – Jebel Ali Port, Dubai (UAE)\r\nCurrency:\r\nUSD (United States Dollar)\r\nBUYER (Importer)\r\nAL NOOR FOODSTUFF TRADING LLC\r\nP.O. Box 47823, Deira, Dubai, United Arab Emirates\r\nTRN (VAT): 100358291200003\r\nContact: Mr. Ahmed Al Rashidi\r\nTel: +971-4-226-8800  |  Email: procurement@alnoorfoods.ae\r\nSELLER (Exporter)\r\nAGRO EXPORTS INDIA PVT. LTD.\r\n123, Nariman Point, Mumbai - 400021, India\r\nIEC: AABCA1234C  |  GSTIN: 27AABCA1234C1Z5\r\nContact: Ms. Priya Sharma\r\nTel: +91-22-4567-8901  |  Email:\r\npriya.sharma@agroexportsindia.com\r\nSHIPMENT & PAYMENT DETAILS\r\nPort of Loading\r\nNhava Sheva (JNPT), Mumbai, India\r\nPayment Terms\r\nIrrevocable LC at Sight (SWIFT MT700)\r\nPort of Discharge\r\nJebel Ali Port, Dubai, UAE\r\nLC Issuing Bank\r\nEmirates NBD, Dubai (SWIFT: EBILAEAD)\r\nMode of Transport\r\nSea Freight – Full Container Load (FCL)\r\nLC Validity\r\n60 days from shipment date\r\nShipment By\r\n30 June 2026 (latest)\r\nPartial Shipment\r\nNot Allowed\r\nContainer Type\r\n1 x 20' GP Container\r\nTranshipment\r\nNot Allowed\r\nORDER LINE ITEMS\r\nSr.\r\nProduct Description\r\nHS Code\r\nQty\r\n(MT)\r\nUnit\r\nPrice (US\r\nD/MT)\r\nAmount\r\n(USD)\r\nCountry of\r\nOrigin\r\n1\r\nBasmati Rice – Grade A Extra Long Grain\r\n(1121 Variety, Aged 2 Years, Sortex Cleaned)\r\nPacking: 25 kg PP Woven Bags\r\n1006.30.2\r\n0\r\n10.0\r\n1,200.00\r\n12,000.00\r\nIndia\r\n2\r\nBasmati Rice – Grade B Long Grain (Pusa\r\n1121, Non-Aged) Packing: 50 kg Jute Bags\r\n1006.30.2\r\n0\r\n5.0\r\n980.00\r\n4,900.00\r\nIndia\r\n3\r\nBroken Basmati Rice (5% Brokens) Packing:\r\n25 kg PP Woven Bags\r\n1006.40.0\r\n0\r\n3.0\r\n620.00\r\n1,860.00\r\nIndia\r\n4\r\nRice Bran Oil – Refined (Edible Grade, 15 kg\r\nTins) Certification: FSSAI & Halal\r\n1514.19.0\r\n0\r\n2.0\r\n1,450.00\r\n2,900.00\r\nIndia\r\nSub-Total (FOB Mumbai)\r\n20 MT\r\n21,660.00\r\nSea Freight (Mumbai → Jebel Ali)\r\n1,200.00\r\nMarine Insurance (0.15% of CIF)\r\n325.00\r\nGRAND TOTAL (CIF Jebel Ali)\r\nUSD 23,1\r\n85.00\r\n\r\nPACKING SPECIFICATIONS\r\n Item 1: 400 bags x 25 kg PP Woven (heat-sealed, double-stitched)\r\n Item 2: 100 bags x 50 kg Food-Grade Jute Bags\r\n Item 3: 120 bags x 25 kg PP Woven Bags\r\n Item 4: 133 tins x 15 kg (food-grade tins, sealed)\r\n All bags: labelled with product name, net/gross wt, batch no., MFG\r\ndate\r\n Total Gross Weight (Est.): ~22,500 kg | Volume: ~38 CBM\r\nQUALITY & CERTIFICATION\r\n Quality inspection by SGS India at origin before shipment\r\n Certificate of Origin (Form A / GSP) – APEDA / Chamber of\r\nCommerce\r\n Phytosanitary Certificate – Ministry of Agriculture, India\r\n FSSAI Certificate (Food Safety)\r\n Halal Certificate (HFSAA Approved Body)\r\n Analysis Report: Moisture, Broken %, Milling degree\r\nBENEFICIARY BANK DETAILS (for LC)\r\nBank Name\r\nState Bank of India, Fort Branch, Mumbai\r\nBranch Address\r\nMumbai Main Branch, Fort, Mumbai - 400001\r\nAccount Name\r\nAgro Exports India Pvt. Ltd.\r\nAccount No.\r\n10234567890\r\nIFSC Code\r\nSBIN0000300\r\nSWIFT Code\r\nSBININBB\r\nBank Reference\r\nLC to be opened 30 days prior to shipment date\r\nTERMS & CONDITIONS\r\n1. Validity: This Purchase Order is valid until 30 June 2026. Seller must confirm acceptance within 5 working days.\r\n2. Shipment: Latest shipment date 30 June 2026. Bill of Lading dated after this date will not be accepted.\r\n3. Documents Required: Signed Commercial Invoice (3 originals), Packing List, Full Set 3/3 OBL, Certificate of Origin, Phytosanitary Certificate, SGS\r\nPre-shipment Inspection Certificate, Halal Certificate, Analysis Report.\r\n4. LC Terms: Buyer will open an Irrevocable LC at Sight within 7 working days of PO acceptance. LC charges outside India are to Buyer's account.\r\n5. Insurance: Seller to arrange marine insurance for 110% of CIF value (Institute Cargo Clauses A).\r\n6. Rejection: Buyer reserves the right to reject goods not conforming to specifications. Rejected goods to be replaced at Seller's cost.\r\n7. Force Majeure: Neither party liable for delays due to natural calamity, war, government restriction, or any event beyond reasonable control.\r\n8. Governing Law: This contract shall be governed by ICC Rules. Disputes to be settled by arbitration in Dubai, UAE.\r\nFOR AL NOOR FOODSTUFF TRADING LLC\r\n_______________________________\r\nAuthorised Signatory\r\nName: Mr. Ahmed Al Rashidi\r\nDesignation: Procurement Manager\r\nDate: _____________\r\nFOR AGRO EXPORTS INDIA PVT. LTD.\r\n_______________________________\r\nAuthorised Signatory\r\nName: Ms. Priya Sharma\r\nDesignation: Director – Exports\r\nDate: _____________\r\nThis is a computer-generated Purchase Order. | Document ID: AEIPL-PO-2026-0542 | Generated: 15-May-2026 | For queries: exports@agroexportsindia.com	\N	2a088130-3a97-49d7-aa89-46f10ad5712d	\N	\N	2026-05-26 14:03:31.343195+00	2026-05-26 14:03:31.343195+00
a1000000-0000-0000-0000-000000000003	00000000-0000-0000-0000-000000000001	EXP-2026-0312	a3000000-0000-0000-0000-000000000001	documents_pending	USD	58000.00	LC	CIF	Mundra Port, Gujarat	Dammam Port	SA	email	\N	\N	\N	\N	\N	2026-05-23 04:41:50.068651+00	2026-05-26 14:27:11.690095+00
f8d73728-3674-4407-b5ac-fbbea6e83d5b	00000000-0000-0000-0000-000000000001	WA-2BF531CE	32ba496a-56cd-4a2d-b27f-b911dbe6b098	awaiting_approval	USD	\N	LC	CIF	\N	\N	AE	portal	\N	\N	\N	\N	\N	2026-05-23 10:10:09.52359+00	2026-05-26 14:27:11.690095+00
e007f8c5-e899-4df0-96cd-4e78a179d4ad	00000000-0000-0000-0000-000000000001	WA-07AA5701	cd8686c4-4b6b-4f35-8edc-0491ba2b488e	awaiting_approval	USD	\N	Letter of Credit (LC)	CIF	\N	Jebel Ali Port, Dubai	AE	portal	\N	\N	\N	\N	\N	2026-05-23 10:20:32.021551+00	2026-05-26 14:27:11.690095+00
05d8b3df-4217-4c05-9b9b-ba4f70032a65	00000000-0000-0000-0000-000000000001	WA-8CCDF40D	039dcf28-d3e9-417d-bab7-d29411a7ab2c	awaiting_approval	USD	\N	LC	CIF	\N	\N	AE	whatsapp	\N	\N	\N	\N	\N	2026-05-23 10:59:39.734005+00	2026-05-26 14:27:11.690095+00
7a954320-49f1-4891-9d65-9a55bea2a7bf	00000000-0000-0000-0000-000000000001	WA-1BD6A794	b5c086c7-1a70-4da4-b59c-c1b780abcd08	awaiting_approval	USD	\N	Letter of Credit (LC)	CIF	\N	Jebel Ali Port, Dubai	AE	portal	\N	\N	\N	\N	\N	2026-05-23 10:22:49.450673+00	2026-05-26 14:27:11.690095+00
40695e75-0bf1-4a0b-93dd-2f1369f99b18	00000000-0000-0000-0000-000000000001	WA-1C1A93AB	fab4633f-fe79-4fcb-9934-189f9153b732	awaiting_approval	USD	\N	Letter of Credit (LC)	CIF	\N	Jebel Ali Port, Dubai	AE	portal	\N	\N	\N	\N	\N	2026-05-23 14:36:38.608424+00	2026-05-26 14:27:11.690095+00
a26a36d4-e72e-41d5-89f0-cbeaf1d3238a	00000000-0000-0000-0000-000000000001	WA-54E67076	b74a832c-38b0-4c98-acfa-20aadcaf3d88	awaiting_approval	USD	\N	Letter of Credit (LC)	CIF	\N	Jebel Ali Port, Dubai	AE	portal	\N	\N	\N	\N	\N	2026-05-23 15:35:43.101721+00	2026-05-26 14:27:11.690095+00
04cfd519-0962-4501-939b-b3f1bef44694	00000000-0000-0000-0000-000000000001	WA-A3C10C06	f97e28f2-3315-4b1b-bcd9-2d750c1648e2	awaiting_approval	USD	\N	LC	CIF	\N	\N	AE	whatsapp	\N	\N	\N	\N	\N	2026-05-23 18:18:52.57315+00	2026-05-26 14:27:11.690095+00
466f4256-1af8-4b0d-8c7b-cb487f62a424	00000000-0000-0000-0000-000000000001	WA-BABBFE69	da61bc37-8db8-4079-83ff-22fcc46fb463	awaiting_approval	USD	\N	LC	CIF	\N	Dubai	AE	whatsapp	\N	\N	\N	\N	\N	2026-05-23 18:49:52.823714+00	2026-05-26 14:27:11.690095+00
b3c7393a-d4d7-4d83-9578-d33b4b6b595f	00000000-0000-0000-0000-000000000001	WA-B21D8655	7bfd5f01-5387-43ed-b4df-ffea3d555881	awaiting_approval	USD	\N	LC	CIF	\N	\N	AE	whatsapp	\N	\N	\N	\N	\N	2026-05-23 22:01:42.930199+00	2026-05-26 14:27:11.690095+00
7593eb00-8939-45a8-91aa-c01d61d71eb6	00000000-0000-0000-0000-000000000001	WA-4B256B9A	c94b7e0d-7996-4404-b850-2f07c45dc0eb	awaiting_approval	USD	\N	LC	CIF	\N	\N	AE	whatsapp	\N	\N	\N	\N	\N	2026-05-23 22:46:02.409492+00	2026-05-26 14:27:11.690095+00
73465a10-33de-432e-a0c7-ab360954f87d	00000000-0000-0000-0000-000000000001	WA-9F717DB9	559ca767-9ca0-4116-b1a3-0986cc81e114	awaiting_approval	USD	\N	LC	CIF	\N	\N	AE	whatsapp	\N	\N	\N	\N	\N	2026-05-24 01:46:38.330125+00	2026-05-26 14:27:11.690095+00
8aa83381-dadc-442b-ad99-13838d6c4fb6	00000000-0000-0000-0000-000000000001	WA-0053D6E0	509a2de7-4020-4465-9a78-d329fb67bcdd	awaiting_approval	USD	\N	LC	CIF	\N	\N	AE	whatsapp	\N	\N	\N	\N	\N	2026-05-24 04:25:02.536213+00	2026-05-26 14:27:11.690095+00
5f1813a0-b2e5-41f8-9d6d-8677d9e2761d	00000000-0000-0000-0000-000000000001	WA-C9AABFAD	7b59098e-015a-4bf4-b8eb-5676d076bc48	awaiting_approval	USD	\N	LC	CIF	\N	\N	AE	whatsapp	\N	\N	\N	\N	\N	2026-05-24 05:26:06.479177+00	2026-05-26 14:27:11.690095+00
c5676919-83b3-4de5-bd32-2d0d828ddbe3	00000000-0000-0000-0000-000000000001	WA-A9D94D8E	0e6fbc91-0555-4157-a152-95321988633f	awaiting_approval	USD	\N	Letter of Credit (LC)	CIF	\N	Jebel Ali Port, Dubai	AE	portal	\N	\N	\N	\N	\N	2026-05-24 13:13:53.575165+00	2026-05-26 14:27:11.690095+00
44326bfa-4345-449a-a05c-1f381b6bc819	00000000-0000-0000-0000-000000000001	WA-6605D66F	d44cc275-96fb-414d-bdcd-71aaf79279b6	awaiting_approval	USD	\N	LC	CIF	\N	Jebel Ali Port	IN	whatsapp	\N	\N	\N	\N	\N	2026-05-26 12:08:07.279152+00	2026-05-26 14:27:11.690095+00
1bc01a0f-3548-4369-9d34-9380c112ce0d	00000000-0000-0000-0000-000000000001	WA-2A1FDF66	814642fc-f4c4-4d0b-9c3f-74eebf5b2c44	awaiting_approval	USD	\N	LC	CIF	\N	Jebel Ali Port	IN	whatsapp	\N	\N	\N	\N	\N	2026-05-26 12:20:51.142354+00	2026-05-26 14:27:11.690095+00
43ce09e7-e284-4c07-b6c9-b95602959f9c	00000000-0000-0000-0000-000000000001	WA-18D2A844	d761b1ac-585b-4718-bed7-a98a9cb987ba	awaiting_approval	USD	\N	LC	CIF	\N	Jebel Ali Port	IN	whatsapp	\N	\N	\N	\N	\N	2026-05-26 13:09:54.314681+00	2026-05-26 14:27:11.690095+00
49e6f162-5a56-4a6e-8fd3-66477c1ecbec	00000000-0000-0000-0000-000000000001	WA-FFFF2F0F	607d9303-1dd5-45ee-9697-29303796ef69	awaiting_approval	USD	\N	LC	CIF	\N	Jebel Ali Port	IN	portal	AGRO EXPORTS INDIA PVT. LTD. IEC: AABCA1234C    GSTIN: 27AABCA1234C1Z5\r\n123, Nariman Point, Mumbai - 400021, Maharashtra, India\r\nTel: +91-22-4567-8900   Email: exports@agroexportsindia.com\r\n Web: www.agroexportsindia.com\r\n \r\nPURCHASE ORDERPO Number:\r\nAEIPL/PO/2026/0542\r\nPO Date:\r\n15 May 2026\r\nValid Until:\r\n30 June 2026\r\nIncoterms:\r\nCIF – Jebel Ali Port, Dubai (UAE)\r\nCurrency:\r\nUSD (United States Dollar)\r\nBUYER (Importer)\r\nAL NOOR FOODSTUFF TRADING LLC\r\nP.O. Box 47823, Deira, Dubai, United Arab Emirates\r\nTRN (VAT): 100358291200003\r\nContact: Mr. Ahmed Al Rashidi\r\nTel: +971-4-226-8800  |  Email: procurement@alnoorfoods.ae\r\nSELLER (Exporter)\r\nAGRO EXPORTS INDIA PVT. LTD.\r\n123, Nariman Point, Mumbai - 400021, India\r\nIEC: AABCA1234C  |  GSTIN: 27AABCA1234C1Z5\r\nContact: Ms. Priya Sharma\r\nTel: +91-22-4567-8901  |  Email:\r\npriya.sharma@agroexportsindia.com\r\nSHIPMENT & PAYMENT DETAILS\r\nPort of Loading\r\nNhava Sheva (JNPT), Mumbai, India\r\nPayment Terms\r\nIrrevocable LC at Sight (SWIFT MT700)\r\nPort of Discharge\r\nJebel Ali Port, Dubai, UAE\r\nLC Issuing Bank\r\nEmirates NBD, Dubai (SWIFT: EBILAEAD)\r\nMode of Transport\r\nSea Freight – Full Container Load (FCL)\r\nLC Validity\r\n60 days from shipment date\r\nShipment By\r\n30 June 2026 (latest)\r\nPartial Shipment\r\nNot Allowed\r\nContainer Type\r\n1 x 20' GP Container\r\nTranshipment\r\nNot Allowed\r\nORDER LINE ITEMS\r\nSr.\r\nProduct Description\r\nHS Code\r\nQty\r\n(MT)\r\nUnit\r\nPrice (US\r\nD/MT)\r\nAmount\r\n(USD)\r\nCountry of\r\nOrigin\r\n1\r\nBasmati Rice – Grade A Extra Long Grain\r\n(1121 Variety, Aged 2 Years, Sortex Cleaned)\r\nPacking: 25 kg PP Woven Bags\r\n1006.30.2\r\n0\r\n10.0\r\n1,200.00\r\n12,000.00\r\nIndia\r\n2\r\nBasmati Rice – Grade B Long Grain (Pusa\r\n1121, Non-Aged) Packing: 50 kg Jute Bags\r\n1006.30.2\r\n0\r\n5.0\r\n980.00\r\n4,900.00\r\nIndia\r\n3\r\nBroken Basmati Rice (5% Brokens) Packing:\r\n25 kg PP Woven Bags\r\n1006.40.0\r\n0\r\n3.0\r\n620.00\r\n1,860.00\r\nIndia\r\n4\r\nRice Bran Oil – Refined (Edible Grade, 15 kg\r\nTins) Certification: FSSAI & Halal\r\n1514.19.0\r\n0\r\n2.0\r\n1,450.00\r\n2,900.00\r\nIndia\r\nSub-Total (FOB Mumbai)\r\n20 MT\r\n21,660.00\r\nSea Freight (Mumbai → Jebel Ali)\r\n1,200.00\r\nMarine Insurance (0.15% of CIF)\r\n325.00\r\nGRAND TOTAL (CIF Jebel Ali)\r\nUSD 23,1\r\n85.00\r\n\r\nPACKING SPECIFICATIONS\r\n Item 1: 400 bags x 25 kg PP Woven (heat-sealed, double-stitched)\r\n Item 2: 100 bags x 50 kg Food-Grade Jute Bags\r\n Item 3: 120 bags x 25 kg PP Woven Bags\r\n Item 4: 133 tins x 15 kg (food-grade tins, sealed)\r\n All bags: labelled with product name, net/gross wt, batch no., MFG\r\ndate\r\n Total Gross Weight (Est.): ~22,500 kg | Volume: ~38 CBM\r\nQUALITY & CERTIFICATION\r\n Quality inspection by SGS India at origin before shipment\r\n Certificate of Origin (Form A / GSP) – APEDA / Chamber of\r\nCommerce\r\n Phytosanitary Certificate – Ministry of Agriculture, India\r\n FSSAI Certificate (Food Safety)\r\n Halal Certificate (HFSAA Approved Body)\r\n Analysis Report: Moisture, Broken %, Milling degree\r\nBENEFICIARY BANK DETAILS (for LC)\r\nBank Name\r\nState Bank of India, Fort Branch, Mumbai\r\nBranch Address\r\nMumbai Main Branch, Fort, Mumbai - 400001\r\nAccount Name\r\nAgro Exports India Pvt. Ltd.\r\nAccount No.\r\n10234567890\r\nIFSC Code\r\nSBIN0000300\r\nSWIFT Code\r\nSBININBB\r\nBank Reference\r\nLC to be opened 30 days prior to shipment date\r\nTERMS & CONDITIONS\r\n1. Validity: This Purchase Order is valid until 30 June 2026. Seller must confirm acceptance within 5 working days.\r\n2. Shipment: Latest shipment date 30 June 2026. Bill of Lading dated after this date will not be accepted.\r\n3. Documents Required: Signed Commercial Invoice (3 originals), Packing List, Full Set 3/3 OBL, Certificate of Origin, Phytosanitary Certificate, SGS\r\nPre-shipment Inspection Certificate, Halal Certificate, Analysis Report.\r\n4. LC Terms: Buyer will open an Irrevocable LC at Sight within 7 working days of PO acceptance. LC charges outside India are to Buyer's account.\r\n5. Insurance: Seller to arrange marine insurance for 110% of CIF value (Institute Cargo Clauses A).\r\n6. Rejection: Buyer reserves the right to reject goods not conforming to specifications. Rejected goods to be replaced at Seller's cost.\r\n7. Force Majeure: Neither party liable for delays due to natural calamity, war, government restriction, or any event beyond reasonable control.\r\n8. Governing Law: This contract shall be governed by ICC Rules. Disputes to be settled by arbitration in Dubai, UAE.\r\nFOR AL NOOR FOODSTUFF TRADING LLC\r\n_______________________________\r\nAuthorised Signatory\r\nName: Mr. Ahmed Al Rashidi\r\nDesignation: Procurement Manager\r\nDate: _____________\r\nFOR AGRO EXPORTS INDIA PVT. LTD.\r\n_______________________________\r\nAuthorised Signatory\r\nName: Ms. Priya Sharma\r\nDesignation: Director – Exports\r\nDate: _____________\r\nThis is a computer-generated Purchase Order. | Document ID: AEIPL-PO-2026-0542 | Generated: 15-May-2026 | For queries: exports@agroexportsindia.com	\N	\N	\N	\N	2026-05-26 14:12:38.632149+00	2026-05-26 14:27:11.690095+00
3748b06b-283f-46a5-8236-1363424dae0a	00000000-0000-0000-0000-000000000001	WA-9963D3E1	df66d47f-b6c4-43c1-a720-76a41af8b230	awaiting_approval	USD	\N	LC	CIF	\N	Jebel Ali Port	IN	portal	AGRO EXPORTS INDIA PVT. LTD. IEC: AABCA1234C    GSTIN: 27AABCA1234C1Z5\r\n123, Nariman Point, Mumbai - 400021, Maharashtra, India\r\nTel: +91-22-4567-8900   Email: exports@agroexportsindia.com\r\n Web: www.agroexportsindia.com\r\n \r\nPURCHASE ORDERPO Number:\r\nAEIPL/PO/2026/0542\r\nPO Date:\r\n15 May 2026\r\nValid Until:\r\n30 June 2026\r\nIncoterms:\r\nCIF – Jebel Ali Port, Dubai (UAE)\r\nCurrency:\r\nUSD (United States Dollar)\r\nBUYER (Importer)\r\nAL NOOR FOODSTUFF TRADING LLC\r\nP.O. Box 47823, Deira, Dubai, United Arab Emirates\r\nTRN (VAT): 100358291200003\r\nContact: Mr. Ahmed Al Rashidi\r\nTel: +971-4-226-8800  |  Email: procurement@alnoorfoods.ae\r\nSELLER (Exporter)\r\nAGRO EXPORTS INDIA PVT. LTD.\r\n123, Nariman Point, Mumbai - 400021, India\r\nIEC: AABCA1234C  |  GSTIN: 27AABCA1234C1Z5\r\nContact: Ms. Priya Sharma\r\nTel: +91-22-4567-8901  |  Email:\r\npriya.sharma@agroexportsindia.com\r\nSHIPMENT & PAYMENT DETAILS\r\nPort of Loading\r\nNhava Sheva (JNPT), Mumbai, India\r\nPayment Terms\r\nIrrevocable LC at Sight (SWIFT MT700)\r\nPort of Discharge\r\nJebel Ali Port, Dubai, UAE\r\nLC Issuing Bank\r\nEmirates NBD, Dubai (SWIFT: EBILAEAD)\r\nMode of Transport\r\nSea Freight – Full Container Load (FCL)\r\nLC Validity\r\n60 days from shipment date\r\nShipment By\r\n30 June 2026 (latest)\r\nPartial Shipment\r\nNot Allowed\r\nContainer Type\r\n1 x 20' GP Container\r\nTranshipment\r\nNot Allowed\r\nORDER LINE ITEMS\r\nSr.\r\nProduct Description\r\nHS Code\r\nQty\r\n(MT)\r\nUnit\r\nPrice (US\r\nD/MT)\r\nAmount\r\n(USD)\r\nCountry of\r\nOrigin\r\n1\r\nBasmati Rice – Grade A Extra Long Grain\r\n(1121 Variety, Aged 2 Years, Sortex Cleaned)\r\nPacking: 25 kg PP Woven Bags\r\n1006.30.2\r\n0\r\n10.0\r\n1,200.00\r\n12,000.00\r\nIndia\r\n2\r\nBasmati Rice – Grade B Long Grain (Pusa\r\n1121, Non-Aged) Packing: 50 kg Jute Bags\r\n1006.30.2\r\n0\r\n5.0\r\n980.00\r\n4,900.00\r\nIndia\r\n3\r\nBroken Basmati Rice (5% Brokens) Packing:\r\n25 kg PP Woven Bags\r\n1006.40.0\r\n0\r\n3.0\r\n620.00\r\n1,860.00\r\nIndia\r\n4\r\nRice Bran Oil – Refined (Edible Grade, 15 kg\r\nTins) Certification: FSSAI & Halal\r\n1514.19.0\r\n0\r\n2.0\r\n1,450.00\r\n2,900.00\r\nIndia\r\nSub-Total (FOB Mumbai)\r\n20 MT\r\n21,660.00\r\nSea Freight (Mumbai → Jebel Ali)\r\n1,200.00\r\nMarine Insurance (0.15% of CIF)\r\n325.00\r\nGRAND TOTAL (CIF Jebel Ali)\r\nUSD 23,1\r\n85.00\r\n\r\nPACKING SPECIFICATIONS\r\n Item 1: 400 bags x 25 kg PP Woven (heat-sealed, double-stitched)\r\n Item 2: 100 bags x 50 kg Food-Grade Jute Bags\r\n Item 3: 120 bags x 25 kg PP Woven Bags\r\n Item 4: 133 tins x 15 kg (food-grade tins, sealed)\r\n All bags: labelled with product name, net/gross wt, batch no., MFG\r\ndate\r\n Total Gross Weight (Est.): ~22,500 kg | Volume: ~38 CBM\r\nQUALITY & CERTIFICATION\r\n Quality inspection by SGS India at origin before shipment\r\n Certificate of Origin (Form A / GSP) – APEDA / Chamber of\r\nCommerce\r\n Phytosanitary Certificate – Ministry of Agriculture, India\r\n FSSAI Certificate (Food Safety)\r\n Halal Certificate (HFSAA Approved Body)\r\n Analysis Report: Moisture, Broken %, Milling degree\r\nBENEFICIARY BANK DETAILS (for LC)\r\nBank Name\r\nState Bank of India, Fort Branch, Mumbai\r\nBranch Address\r\nMumbai Main Branch, Fort, Mumbai - 400001\r\nAccount Name\r\nAgro Exports India Pvt. Ltd.\r\nAccount No.\r\n10234567890\r\nIFSC Code\r\nSBIN0000300\r\nSWIFT Code\r\nSBININBB\r\nBank Reference\r\nLC to be opened 30 days prior to shipment date\r\nTERMS & CONDITIONS\r\n1. Validity: This Purchase Order is valid until 30 June 2026. Seller must confirm acceptance within 5 working days.\r\n2. Shipment: Latest shipment date 30 June 2026. Bill of Lading dated after this date will not be accepted.\r\n3. Documents Required: Signed Commercial Invoice (3 originals), Packing List, Full Set 3/3 OBL, Certificate of Origin, Phytosanitary Certificate, SGS\r\nPre-shipment Inspection Certificate, Halal Certificate, Analysis Report.\r\n4. LC Terms: Buyer will open an Irrevocable LC at Sight within 7 working days of PO acceptance. LC charges outside India are to Buyer's account.\r\n5. Insurance: Seller to arrange marine insurance for 110% of CIF value (Institute Cargo Clauses A).\r\n6. Rejection: Buyer reserves the right to reject goods not conforming to specifications. Rejected goods to be replaced at Seller's cost.\r\n7. Force Majeure: Neither party liable for delays due to natural calamity, war, government restriction, or any event beyond reasonable control.\r\n8. Governing Law: This contract shall be governed by ICC Rules. Disputes to be settled by arbitration in Dubai, UAE.\r\nFOR AL NOOR FOODSTUFF TRADING LLC\r\n_______________________________\r\nAuthorised Signatory\r\nName: Mr. Ahmed Al Rashidi\r\nDesignation: Procurement Manager\r\nDate: _____________\r\nFOR AGRO EXPORTS INDIA PVT. LTD.\r\n_______________________________\r\nAuthorised Signatory\r\nName: Ms. Priya Sharma\r\nDesignation: Director – Exports\r\nDate: _____________\r\nThis is a computer-generated Purchase Order. | Document ID: AEIPL-PO-2026-0542 | Generated: 15-May-2026 | For queries: exports@agroexportsindia.com	\N	\N	\N	\N	2026-05-26 14:17:15.341887+00	2026-05-26 14:27:11.690095+00
201fcbaa-36b8-4632-97c4-ad4e13c949b6	00000000-0000-0000-0000-000000000001	WA-14076011	21fb391f-8396-4d4d-8215-5391de91afa4	awaiting_approval	USD	\N	LC	CIF	\N	Jebel Ali Port	IN	portal	AGRO EXPORTS INDIA PVT. LTD. IEC: AABCA1234C    GSTIN: 27AABCA1234C1Z5\r\n123, Nariman Point, Mumbai - 400021, Maharashtra, India\r\nTel: +91-22-4567-8900   Email: exports@agroexportsindia.com\r\n Web: www.agroexportsindia.com\r\n \r\nPURCHASE ORDERPO Number:\r\nAEIPL/PO/2026/0542\r\nPO Date:\r\n15 May 2026\r\nValid Until:\r\n30 June 2026\r\nIncoterms:\r\nCIF – Jebel Ali Port, Dubai (UAE)\r\nCurrency:\r\nUSD (United States Dollar)\r\nBUYER (Importer)\r\nAL NOOR FOODSTUFF TRADING LLC\r\nP.O. Box 47823, Deira, Dubai, United Arab Emirates\r\nTRN (VAT): 100358291200003\r\nContact: Mr. Ahmed Al Rashidi\r\nTel: +971-4-226-8800  |  Email: procurement@alnoorfoods.ae\r\nSELLER (Exporter)\r\nAGRO EXPORTS INDIA PVT. LTD.\r\n123, Nariman Point, Mumbai - 400021, India\r\nIEC: AABCA1234C  |  GSTIN: 27AABCA1234C1Z5\r\nContact: Ms. Priya Sharma\r\nTel: +91-22-4567-8901  |  Email:\r\npriya.sharma@agroexportsindia.com\r\nSHIPMENT & PAYMENT DETAILS\r\nPort of Loading\r\nNhava Sheva (JNPT), Mumbai, India\r\nPayment Terms\r\nIrrevocable LC at Sight (SWIFT MT700)\r\nPort of Discharge\r\nJebel Ali Port, Dubai, UAE\r\nLC Issuing Bank\r\nEmirates NBD, Dubai (SWIFT: EBILAEAD)\r\nMode of Transport\r\nSea Freight – Full Container Load (FCL)\r\nLC Validity\r\n60 days from shipment date\r\nShipment By\r\n30 June 2026 (latest)\r\nPartial Shipment\r\nNot Allowed\r\nContainer Type\r\n1 x 20' GP Container\r\nTranshipment\r\nNot Allowed\r\nORDER LINE ITEMS\r\nSr.\r\nProduct Description\r\nHS Code\r\nQty\r\n(MT)\r\nUnit\r\nPrice (US\r\nD/MT)\r\nAmount\r\n(USD)\r\nCountry of\r\nOrigin\r\n1\r\nBasmati Rice – Grade A Extra Long Grain\r\n(1121 Variety, Aged 2 Years, Sortex Cleaned)\r\nPacking: 25 kg PP Woven Bags\r\n1006.30.2\r\n0\r\n10.0\r\n1,200.00\r\n12,000.00\r\nIndia\r\n2\r\nBasmati Rice – Grade B Long Grain (Pusa\r\n1121, Non-Aged) Packing: 50 kg Jute Bags\r\n1006.30.2\r\n0\r\n5.0\r\n980.00\r\n4,900.00\r\nIndia\r\n3\r\nBroken Basmati Rice (5% Brokens) Packing:\r\n25 kg PP Woven Bags\r\n1006.40.0\r\n0\r\n3.0\r\n620.00\r\n1,860.00\r\nIndia\r\n4\r\nRice Bran Oil – Refined (Edible Grade, 15 kg\r\nTins) Certification: FSSAI & Halal\r\n1514.19.0\r\n0\r\n2.0\r\n1,450.00\r\n2,900.00\r\nIndia\r\nSub-Total (FOB Mumbai)\r\n20 MT\r\n21,660.00\r\nSea Freight (Mumbai → Jebel Ali)\r\n1,200.00\r\nMarine Insurance (0.15% of CIF)\r\n325.00\r\nGRAND TOTAL (CIF Jebel Ali)\r\nUSD 23,1\r\n85.00\r\n\r\nPACKING SPECIFICATIONS\r\n Item 1: 400 bags x 25 kg PP Woven (heat-sealed, double-stitched)\r\n Item 2: 100 bags x 50 kg Food-Grade Jute Bags\r\n Item 3: 120 bags x 25 kg PP Woven Bags\r\n Item 4: 133 tins x 15 kg (food-grade tins, sealed)\r\n All bags: labelled with product name, net/gross wt, batch no., MFG\r\ndate\r\n Total Gross Weight (Est.): ~22,500 kg | Volume: ~38 CBM\r\nQUALITY & CERTIFICATION\r\n Quality inspection by SGS India at origin before shipment\r\n Certificate of Origin (Form A / GSP) – APEDA / Chamber of\r\nCommerce\r\n Phytosanitary Certificate – Ministry of Agriculture, India\r\n FSSAI Certificate (Food Safety)\r\n Halal Certificate (HFSAA Approved Body)\r\n Analysis Report: Moisture, Broken %, Milling degree\r\nBENEFICIARY BANK DETAILS (for LC)\r\nBank Name\r\nState Bank of India, Fort Branch, Mumbai\r\nBranch Address\r\nMumbai Main Branch, Fort, Mumbai - 400001\r\nAccount Name\r\nAgro Exports India Pvt. Ltd.\r\nAccount No.\r\n10234567890\r\nIFSC Code\r\nSBIN0000300\r\nSWIFT Code\r\nSBININBB\r\nBank Reference\r\nLC to be opened 30 days prior to shipment date\r\nTERMS & CONDITIONS\r\n1. Validity: This Purchase Order is valid until 30 June 2026. Seller must confirm acceptance within 5 working days.\r\n2. Shipment: Latest shipment date 30 June 2026. Bill of Lading dated after this date will not be accepted.\r\n3. Documents Required: Signed Commercial Invoice (3 originals), Packing List, Full Set 3/3 OBL, Certificate of Origin, Phytosanitary Certificate, SGS\r\nPre-shipment Inspection Certificate, Halal Certificate, Analysis Report.\r\n4. LC Terms: Buyer will open an Irrevocable LC at Sight within 7 working days of PO acceptance. LC charges outside India are to Buyer's account.\r\n5. Insurance: Seller to arrange marine insurance for 110% of CIF value (Institute Cargo Clauses A).\r\n6. Rejection: Buyer reserves the right to reject goods not conforming to specifications. Rejected goods to be replaced at Seller's cost.\r\n7. Force Majeure: Neither party liable for delays due to natural calamity, war, government restriction, or any event beyond reasonable control.\r\n8. Governing Law: This contract shall be governed by ICC Rules. Disputes to be settled by arbitration in Dubai, UAE.\r\nFOR AL NOOR FOODSTUFF TRADING LLC\r\n_______________________________\r\nAuthorised Signatory\r\nName: Mr. Ahmed Al Rashidi\r\nDesignation: Procurement Manager\r\nDate: _____________\r\nFOR AGRO EXPORTS INDIA PVT. LTD.\r\n_______________________________\r\nAuthorised Signatory\r\nName: Ms. Priya Sharma\r\nDesignation: Director – Exports\r\nDate: _____________\r\nThis is a computer-generated Purchase Order. | Document ID: AEIPL-PO-2026-0542 | Generated: 15-May-2026 | For queries: exports@agroexportsindia.com	\N	\N	\N	\N	2026-05-26 14:18:57.688648+00	2026-05-26 14:27:11.690095+00
61bf1aff-4989-45a3-a1ed-7d412e935110	00000000-0000-0000-0000-000000000001	WA-4C708809	4c353781-3ada-4ef4-9a4b-da3790a30b19	awaiting_approval	USD	\N	LC	CIF	\N	Port Of Loading	AE	portal	Please process the following Purchase Order for Dhiraj Group:\r\n\r\nBuyer Details:\r\nCompany Name: Dhiraj Group\r\nAddress: 456 Business Avenue, Business Bay, Dubai, United Arab Emirates\r\nCountry: UAE\r\nVAT/TRN: 100293847563\r\n\r\nItem Details:\r\nProduct: Dell Latitude 7420 Laptops\r\nArabic Description: كمبيوتر محمول ديل لاتيتيود 7420\r\nQuantity: 100 PCS\r\nUnit Price: USD 300 / PC\r\nTotal Value: USD 30,000\r\nCountry of Origin: USA\r\nHS Code: 84713010\r\n\r\nShipping & Logistics:\r\nIncoterms: CIF\r\nPort of Loading: Nhava Sheva, Mumbai, India\r\nDestination Port: Jebel Ali Port, Dubai\r\nCountry of Final Destination: United Arab Emirates\r\nPre-Carriage: Road Transport\r\nVessel/Flight: Ocean Freight\r\nExpected Delivery Date: 15 November 2026\r\n\r\nTerms & Instructions:\r\nPayment Terms: Letter of Credit (LC)\r\nLC Number: LC-987654321\r\nIssuing Bank: Emirates NBD Dubai\r\nLC Expiry Date: 31 December 2026\r\nLUT/Bond Number: LUT-2026-98765\r\n\r\nPacking Instructions:\r\nStandard Export Packaging. 100 Laptops packed in 10 master cartons (10 laptops per carton).\r\nCarton Dimensions: 50cm x 40cm x 30cm.\r\nNet Weight per carton: 13 kg.\r\nGross Weight per carton: 15.5 kg.	\N	\N	\N	\N	2026-05-26 14:10:49.30603+00	2026-05-26 14:27:11.690095+00
bedf49e1-9a2c-4696-aca1-d0872eb0a7e7	00000000-0000-0000-0000-000000000001	WA-658B178A	410cbeda-1cfd-431f-aaa2-64c8f2cc9b5d	awaiting_approval	USD	\N	LC	CIF	\N	Port Of Loading	AE	portal	Please process the following Purchase Order for Dhiraj Group:\r\n\r\nBuyer Details:\r\nCompany Name: Dhiraj Group\r\nAddress: 456 Business Avenue, Business Bay, Dubai, United Arab Emirates\r\nCountry: UAE\r\nVAT/TRN: 100293847563\r\n\r\nItem Details:\r\nProduct: Dell Latitude 7420 Laptops\r\nArabic Description: كمبيوتر محمول ديل لاتيتيود 7420\r\nQuantity: 100 PCS\r\nUnit Price: USD 300 / PC\r\nTotal Value: USD 30,000\r\nCountry of Origin: USA\r\nHS Code: 84713010\r\n\r\nShipping & Logistics:\r\nIncoterms: CIF\r\nPort of Loading: Nhava Sheva, Mumbai, India\r\nDestination Port: Jebel Ali Port, Dubai\r\nCountry of Final Destination: United Arab Emirates\r\nPre-Carriage: Road Transport\r\nVessel/Flight: Ocean Freight\r\nExpected Delivery Date: 15 November 2026\r\n\r\nTerms & Instructions:\r\nPayment Terms: Letter of Credit (LC)\r\nLC Number: LC-987654321\r\nIssuing Bank: Emirates NBD Dubai\r\nLC Expiry Date: 31 December 2026\r\nLUT/Bond Number: LUT-2026-98765\r\n\r\nPacking Instructions:\r\nStandard Export Packaging. 100 Laptops packed in 10 master cartons (10 laptops per carton).\r\nCarton Dimensions: 50cm x 40cm x 30cm.\r\nNet Weight per carton: 13 kg.\r\nGross Weight per carton: 15.5 kg.	\N	\N	\N	\N	2026-05-26 14:11:46.328808+00	2026-05-26 14:27:11.690095+00
b8da2259-5723-4907-950c-c6c3ce4783bb	00000000-0000-0000-0000-000000000001	WA-283DA19A	203565af-55da-42da-ba48-e676d0f5c902	awaiting_approval	USD	\N	LC	CIF	\N	Jebel Ali Port	IN	portal	AGRO EXPORTS INDIA PVT. LTD. IEC: AABCA1234C    GSTIN: 27AABCA1234C1Z5\r\n123, Nariman Point, Mumbai - 400021, Maharashtra, India\r\nTel: +91-22-4567-8900   Email: exports@agroexportsindia.com\r\n Web: www.agroexportsindia.com\r\n \r\nPURCHASE ORDERPO Number:\r\nAEIPL/PO/2026/0542\r\nPO Date:\r\n15 May 2026\r\nValid Until:\r\n30 June 2026\r\nIncoterms:\r\nCIF – Jebel Ali Port, Dubai (UAE)\r\nCurrency:\r\nUSD (United States Dollar)\r\nBUYER (Importer)\r\nAL NOOR FOODSTUFF TRADING LLC\r\nP.O. Box 47823, Deira, Dubai, United Arab Emirates\r\nTRN (VAT): 100358291200003\r\nContact: Mr. Ahmed Al Rashidi\r\nTel: +971-4-226-8800  |  Email: procurement@alnoorfoods.ae\r\nSELLER (Exporter)\r\nAGRO EXPORTS INDIA PVT. LTD.\r\n123, Nariman Point, Mumbai - 400021, India\r\nIEC: AABCA1234C  |  GSTIN: 27AABCA1234C1Z5\r\nContact: Ms. Priya Sharma\r\nTel: +91-22-4567-8901  |  Email:\r\npriya.sharma@agroexportsindia.com\r\nSHIPMENT & PAYMENT DETAILS\r\nPort of Loading\r\nNhava Sheva (JNPT), Mumbai, India\r\nPayment Terms\r\nIrrevocable LC at Sight (SWIFT MT700)\r\nPort of Discharge\r\nJebel Ali Port, Dubai, UAE\r\nLC Issuing Bank\r\nEmirates NBD, Dubai (SWIFT: EBILAEAD)\r\nMode of Transport\r\nSea Freight – Full Container Load (FCL)\r\nLC Validity\r\n60 days from shipment date\r\nShipment By\r\n30 June 2026 (latest)\r\nPartial Shipment\r\nNot Allowed\r\nContainer Type\r\n1 x 20' GP Container\r\nTranshipment\r\nNot Allowed\r\nORDER LINE ITEMS\r\nSr.\r\nProduct Description\r\nHS Code\r\nQty\r\n(MT)\r\nUnit\r\nPrice (US\r\nD/MT)\r\nAmount\r\n(USD)\r\nCountry of\r\nOrigin\r\n1\r\nBasmati Rice – Grade A Extra Long Grain\r\n(1121 Variety, Aged 2 Years, Sortex Cleaned)\r\nPacking: 25 kg PP Woven Bags\r\n1006.30.2\r\n0\r\n10.0\r\n1,200.00\r\n12,000.00\r\nIndia\r\n2\r\nBasmati Rice – Grade B Long Grain (Pusa\r\n1121, Non-Aged) Packing: 50 kg Jute Bags\r\n1006.30.2\r\n0\r\n5.0\r\n980.00\r\n4,900.00\r\nIndia\r\n3\r\nBroken Basmati Rice (5% Brokens) Packing:\r\n25 kg PP Woven Bags\r\n1006.40.0\r\n0\r\n3.0\r\n620.00\r\n1,860.00\r\nIndia\r\n4\r\nRice Bran Oil – Refined (Edible Grade, 15 kg\r\nTins) Certification: FSSAI & Halal\r\n1514.19.0\r\n0\r\n2.0\r\n1,450.00\r\n2,900.00\r\nIndia\r\nSub-Total (FOB Mumbai)\r\n20 MT\r\n21,660.00\r\nSea Freight (Mumbai → Jebel Ali)\r\n1,200.00\r\nMarine Insurance (0.15% of CIF)\r\n325.00\r\nGRAND TOTAL (CIF Jebel Ali)\r\nUSD 23,1\r\n85.00\r\n\r\nPACKING SPECIFICATIONS\r\n Item 1: 400 bags x 25 kg PP Woven (heat-sealed, double-stitched)\r\n Item 2: 100 bags x 50 kg Food-Grade Jute Bags\r\n Item 3: 120 bags x 25 kg PP Woven Bags\r\n Item 4: 133 tins x 15 kg (food-grade tins, sealed)\r\n All bags: labelled with product name, net/gross wt, batch no., MFG\r\ndate\r\n Total Gross Weight (Est.): ~22,500 kg | Volume: ~38 CBM\r\nQUALITY & CERTIFICATION\r\n Quality inspection by SGS India at origin before shipment\r\n Certificate of Origin (Form A / GSP) – APEDA / Chamber of\r\nCommerce\r\n Phytosanitary Certificate – Ministry of Agriculture, India\r\n FSSAI Certificate (Food Safety)\r\n Halal Certificate (HFSAA Approved Body)\r\n Analysis Report: Moisture, Broken %, Milling degree\r\nBENEFICIARY BANK DETAILS (for LC)\r\nBank Name\r\nState Bank of India, Fort Branch, Mumbai\r\nBranch Address\r\nMumbai Main Branch, Fort, Mumbai - 400001\r\nAccount Name\r\nAgro Exports India Pvt. Ltd.\r\nAccount No.\r\n10234567890\r\nIFSC Code\r\nSBIN0000300\r\nSWIFT Code\r\nSBININBB\r\nBank Reference\r\nLC to be opened 30 days prior to shipment date\r\nTERMS & CONDITIONS\r\n1. Validity: This Purchase Order is valid until 30 June 2026. Seller must confirm acceptance within 5 working days.\r\n2. Shipment: Latest shipment date 30 June 2026. Bill of Lading dated after this date will not be accepted.\r\n3. Documents Required: Signed Commercial Invoice (3 originals), Packing List, Full Set 3/3 OBL, Certificate of Origin, Phytosanitary Certificate, SGS\r\nPre-shipment Inspection Certificate, Halal Certificate, Analysis Report.\r\n4. LC Terms: Buyer will open an Irrevocable LC at Sight within 7 working days of PO acceptance. LC charges outside India are to Buyer's account.\r\n5. Insurance: Seller to arrange marine insurance for 110% of CIF value (Institute Cargo Clauses A).\r\n6. Rejection: Buyer reserves the right to reject goods not conforming to specifications. Rejected goods to be replaced at Seller's cost.\r\n7. Force Majeure: Neither party liable for delays due to natural calamity, war, government restriction, or any event beyond reasonable control.\r\n8. Governing Law: This contract shall be governed by ICC Rules. Disputes to be settled by arbitration in Dubai, UAE.\r\nFOR AL NOOR FOODSTUFF TRADING LLC\r\n_______________________________\r\nAuthorised Signatory\r\nName: Mr. Ahmed Al Rashidi\r\nDesignation: Procurement Manager\r\nDate: _____________\r\nFOR AGRO EXPORTS INDIA PVT. LTD.\r\n_______________________________\r\nAuthorised Signatory\r\nName: Ms. Priya Sharma\r\nDesignation: Director – Exports\r\nDate: _____________\r\nThis is a computer-generated Purchase Order. | Document ID: AEIPL-PO-2026-0542 | Generated: 15-May-2026 | For queries: exports@agroexportsindia.com	\N	\N	\N	\N	2026-05-26 14:19:17.239076+00	2026-05-26 14:27:11.690095+00
618cbe23-4cd8-4c4e-8b26-75e85183e593	00000000-0000-0000-0000-000000000001	WA-B6063DFB	5285d8e8-c354-4f05-b27e-b5ed779b3424	awaiting_approval	USD	\N	LC	CIF	\N	Jebel Ali Port	IN	portal	AGRO EXPORTS INDIA PVT. LTD. IEC: AABCA1234C    GSTIN: 27AABCA1234C1Z5\r\n123, Nariman Point, Mumbai - 400021, Maharashtra, India\r\nTel: +91-22-4567-8900   Email: exports@agroexportsindia.com\r\n Web: www.agroexportsindia.com\r\n \r\nPURCHASE ORDERPO Number:\r\nAEIPL/PO/2026/0542\r\nPO Date:\r\n15 May 2026\r\nValid Until:\r\n30 June 2026\r\nIncoterms:\r\nCIF – Jebel Ali Port, Dubai (UAE)\r\nCurrency:\r\nUSD (United States Dollar)\r\nBUYER (Importer)\r\nAL NOOR FOODSTUFF TRADING LLC\r\nP.O. Box 47823, Deira, Dubai, United Arab Emirates\r\nTRN (VAT): 100358291200003\r\nContact: Mr. Ahmed Al Rashidi\r\nTel: +971-4-226-8800  |  Email: procurement@alnoorfoods.ae\r\nSELLER (Exporter)\r\nAGRO EXPORTS INDIA PVT. LTD.\r\n123, Nariman Point, Mumbai - 400021, India\r\nIEC: AABCA1234C  |  GSTIN: 27AABCA1234C1Z5\r\nContact: Ms. Priya Sharma\r\nTel: +91-22-4567-8901  |  Email:\r\npriya.sharma@agroexportsindia.com\r\nSHIPMENT & PAYMENT DETAILS\r\nPort of Loading\r\nNhava Sheva (JNPT), Mumbai, India\r\nPayment Terms\r\nIrrevocable LC at Sight (SWIFT MT700)\r\nPort of Discharge\r\nJebel Ali Port, Dubai, UAE\r\nLC Issuing Bank\r\nEmirates NBD, Dubai (SWIFT: EBILAEAD)\r\nMode of Transport\r\nSea Freight – Full Container Load (FCL)\r\nLC Validity\r\n60 days from shipment date\r\nShipment By\r\n30 June 2026 (latest)\r\nPartial Shipment\r\nNot Allowed\r\nContainer Type\r\n1 x 20' GP Container\r\nTranshipment\r\nNot Allowed\r\nORDER LINE ITEMS\r\nSr.\r\nProduct Description\r\nHS Code\r\nQty\r\n(MT)\r\nUnit\r\nPrice (US\r\nD/MT)\r\nAmount\r\n(USD)\r\nCountry of\r\nOrigin\r\n1\r\nBasmati Rice – Grade A Extra Long Grain\r\n(1121 Variety, Aged 2 Years, Sortex Cleaned)\r\nPacking: 25 kg PP Woven Bags\r\n1006.30.2\r\n0\r\n10.0\r\n1,200.00\r\n12,000.00\r\nIndia\r\n2\r\nBasmati Rice – Grade B Long Grain (Pusa\r\n1121, Non-Aged) Packing: 50 kg Jute Bags\r\n1006.30.2\r\n0\r\n5.0\r\n980.00\r\n4,900.00\r\nIndia\r\n3\r\nBroken Basmati Rice (5% Brokens) Packing:\r\n25 kg PP Woven Bags\r\n1006.40.0\r\n0\r\n3.0\r\n620.00\r\n1,860.00\r\nIndia\r\n4\r\nRice Bran Oil – Refined (Edible Grade, 15 kg\r\nTins) Certification: FSSAI & Halal\r\n1514.19.0\r\n0\r\n2.0\r\n1,450.00\r\n2,900.00\r\nIndia\r\nSub-Total (FOB Mumbai)\r\n20 MT\r\n21,660.00\r\nSea Freight (Mumbai → Jebel Ali)\r\n1,200.00\r\nMarine Insurance (0.15% of CIF)\r\n325.00\r\nGRAND TOTAL (CIF Jebel Ali)\r\nUSD 23,1\r\n85.00\r\n\r\nPACKING SPECIFICATIONS\r\n Item 1: 400 bags x 25 kg PP Woven (heat-sealed, double-stitched)\r\n Item 2: 100 bags x 50 kg Food-Grade Jute Bags\r\n Item 3: 120 bags x 25 kg PP Woven Bags\r\n Item 4: 133 tins x 15 kg (food-grade tins, sealed)\r\n All bags: labelled with product name, net/gross wt, batch no., MFG\r\ndate\r\n Total Gross Weight (Est.): ~22,500 kg | Volume: ~38 CBM\r\nQUALITY & CERTIFICATION\r\n Quality inspection by SGS India at origin before shipment\r\n Certificate of Origin (Form A / GSP) – APEDA / Chamber of\r\nCommerce\r\n Phytosanitary Certificate – Ministry of Agriculture, India\r\n FSSAI Certificate (Food Safety)\r\n Halal Certificate (HFSAA Approved Body)\r\n Analysis Report: Moisture, Broken %, Milling degree\r\nBENEFICIARY BANK DETAILS (for LC)\r\nBank Name\r\nState Bank of India, Fort Branch, Mumbai\r\nBranch Address\r\nMumbai Main Branch, Fort, Mumbai - 400001\r\nAccount Name\r\nAgro Exports India Pvt. Ltd.\r\nAccount No.\r\n10234567890\r\nIFSC Code\r\nSBIN0000300\r\nSWIFT Code\r\nSBININBB\r\nBank Reference\r\nLC to be opened 30 days prior to shipment date\r\nTERMS & CONDITIONS\r\n1. Validity: This Purchase Order is valid until 30 June 2026. Seller must confirm acceptance within 5 working days.\r\n2. Shipment: Latest shipment date 30 June 2026. Bill of Lading dated after this date will not be accepted.\r\n3. Documents Required: Signed Commercial Invoice (3 originals), Packing List, Full Set 3/3 OBL, Certificate of Origin, Phytosanitary Certificate, SGS\r\nPre-shipment Inspection Certificate, Halal Certificate, Analysis Report.\r\n4. LC Terms: Buyer will open an Irrevocable LC at Sight within 7 working days of PO acceptance. LC charges outside India are to Buyer's account.\r\n5. Insurance: Seller to arrange marine insurance for 110% of CIF value (Institute Cargo Clauses A).\r\n6. Rejection: Buyer reserves the right to reject goods not conforming to specifications. Rejected goods to be replaced at Seller's cost.\r\n7. Force Majeure: Neither party liable for delays due to natural calamity, war, government restriction, or any event beyond reasonable control.\r\n8. Governing Law: This contract shall be governed by ICC Rules. Disputes to be settled by arbitration in Dubai, UAE.\r\nFOR AL NOOR FOODSTUFF TRADING LLC\r\n_______________________________\r\nAuthorised Signatory\r\nName: Mr. Ahmed Al Rashidi\r\nDesignation: Procurement Manager\r\nDate: _____________\r\nFOR AGRO EXPORTS INDIA PVT. LTD.\r\n_______________________________\r\nAuthorised Signatory\r\nName: Ms. Priya Sharma\r\nDesignation: Director – Exports\r\nDate: _____________\r\nThis is a computer-generated Purchase Order. | Document ID: AEIPL-PO-2026-0542 | Generated: 15-May-2026 | For queries: exports@agroexportsindia.com	\N	\N	\N	\N	2026-05-26 14:22:39.627366+00	2026-05-26 14:27:11.690095+00
06a315f6-2b3d-41b0-9d50-8add173013bc	00000000-0000-0000-0000-000000000001	WA-D3E3B946	e206ee52-05e4-44f6-bed5-501172701af7	awaiting_approval	USD	\N	LC	CIF	\N	Port Of Loading	AE	portal	Please process the following Purchase Order for Dhiraj Group:\r\n\r\nBuyer Details:\r\nCompany Name: Dhiraj Group\r\nAddress: 456 Business Avenue, Business Bay, Dubai, United Arab Emirates\r\nCountry: UAE\r\nVAT/TRN: 100293847563\r\n\r\nItem Details:\r\nProduct: Dell Latitude 7420 Laptops\r\nArabic Description: كمبيوتر محمول ديل لاتيتيود 7420\r\nQuantity: 100 PCS\r\nUnit Price: USD 300 / PC\r\nTotal Value: USD 30,000\r\nCountry of Origin: USA\r\nHS Code: 84713010\r\n\r\nShipping & Logistics:\r\nIncoterms: CIF\r\nPort of Loading: Nhava Sheva, Mumbai, India\r\nDestination Port: Jebel Ali Port, Dubai\r\nCountry of Final Destination: United Arab Emirates\r\nPre-Carriage: Road Transport\r\nVessel/Flight: Ocean Freight\r\nExpected Delivery Date: 15 November 2026\r\n\r\nTerms & Instructions:\r\nPayment Terms: Letter of Credit (LC)\r\nLC Number: LC-987654321\r\nIssuing Bank: Emirates NBD Dubai\r\nLC Expiry Date: 31 December 2026\r\nLUT/Bond Number: LUT-2026-98765\r\n\r\nPacking Instructions:\r\nStandard Export Packaging. 100 Laptops packed in 10 master cartons (10 laptops per carton).\r\nCarton Dimensions: 50cm x 40cm x 30cm.\r\nNet Weight per carton: 13 kg.\r\nGross Weight per carton: 15.5 kg.	\N	\N	\N	\N	2026-05-26 14:26:24.986181+00	2026-05-26 14:27:11.690095+00
a368e2e7-5d54-4a1d-b967-14e4a39caf1e	00000000-0000-0000-0000-000000000001	WA-861458B2	57863633-f2fd-460e-80be-fbe8d1bd4a2b	awaiting_approval	USD	\N	LC	CIF	\N	Jebel Ali Port	IN	portal	AGRO EXPORTS INDIA PVT. LTD. IEC: AABCA1234C    GSTIN: 27AABCA1234C1Z5\r\n123, Nariman Point, Mumbai - 400021, Maharashtra, India\r\nTel: +91-22-4567-8900   Email: exports@agroexportsindia.com\r\n Web: www.agroexportsindia.com\r\n \r\nPURCHASE ORDERPO Number:\r\nAEIPL/PO/2026/0542\r\nPO Date:\r\n15 May 2026\r\nValid Until:\r\n30 June 2026\r\nIncoterms:\r\nCIF – Jebel Ali Port, Dubai (UAE)\r\nCurrency:\r\nUSD (United States Dollar)\r\nBUYER (Importer)\r\nAL NOOR FOODSTUFF TRADING LLC\r\nP.O. Box 47823, Deira, Dubai, United Arab Emirates\r\nTRN (VAT): 100358291200003\r\nContact: Mr. Ahmed Al Rashidi\r\nTel: +971-4-226-8800  |  Email: procurement@alnoorfoods.ae\r\nSELLER (Exporter)\r\nAGRO EXPORTS INDIA PVT. LTD.\r\n123, Nariman Point, Mumbai - 400021, India\r\nIEC: AABCA1234C  |  GSTIN: 27AABCA1234C1Z5\r\nContact: Ms. Priya Sharma\r\nTel: +91-22-4567-8901  |  Email:\r\npriya.sharma@agroexportsindia.com\r\nSHIPMENT & PAYMENT DETAILS\r\nPort of Loading\r\nNhava Sheva (JNPT), Mumbai, India\r\nPayment Terms\r\nIrrevocable LC at Sight (SWIFT MT700)\r\nPort of Discharge\r\nJebel Ali Port, Dubai, UAE\r\nLC Issuing Bank\r\nEmirates NBD, Dubai (SWIFT: EBILAEAD)\r\nMode of Transport\r\nSea Freight – Full Container Load (FCL)\r\nLC Validity\r\n60 days from shipment date\r\nShipment By\r\n30 June 2026 (latest)\r\nPartial Shipment\r\nNot Allowed\r\nContainer Type\r\n1 x 20' GP Container\r\nTranshipment\r\nNot Allowed\r\nORDER LINE ITEMS\r\nSr.\r\nProduct Description\r\nHS Code\r\nQty\r\n(MT)\r\nUnit\r\nPrice (US\r\nD/MT)\r\nAmount\r\n(USD)\r\nCountry of\r\nOrigin\r\n1\r\nBasmati Rice – Grade A Extra Long Grain\r\n(1121 Variety, Aged 2 Years, Sortex Cleaned)\r\nPacking: 25 kg PP Woven Bags\r\n1006.30.2\r\n0\r\n10.0\r\n1,200.00\r\n12,000.00\r\nIndia\r\n2\r\nBasmati Rice – Grade B Long Grain (Pusa\r\n1121, Non-Aged) Packing: 50 kg Jute Bags\r\n1006.30.2\r\n0\r\n5.0\r\n980.00\r\n4,900.00\r\nIndia\r\n3\r\nBroken Basmati Rice (5% Brokens) Packing:\r\n25 kg PP Woven Bags\r\n1006.40.0\r\n0\r\n3.0\r\n620.00\r\n1,860.00\r\nIndia\r\n4\r\nRice Bran Oil – Refined (Edible Grade, 15 kg\r\nTins) Certification: FSSAI & Halal\r\n1514.19.0\r\n0\r\n2.0\r\n1,450.00\r\n2,900.00\r\nIndia\r\nSub-Total (FOB Mumbai)\r\n20 MT\r\n21,660.00\r\nSea Freight (Mumbai → Jebel Ali)\r\n1,200.00\r\nMarine Insurance (0.15% of CIF)\r\n325.00\r\nGRAND TOTAL (CIF Jebel Ali)\r\nUSD 23,1\r\n85.00\r\n\r\nPACKING SPECIFICATIONS\r\n Item 1: 400 bags x 25 kg PP Woven (heat-sealed, double-stitched)\r\n Item 2: 100 bags x 50 kg Food-Grade Jute Bags\r\n Item 3: 120 bags x 25 kg PP Woven Bags\r\n Item 4: 133 tins x 15 kg (food-grade tins, sealed)\r\n All bags: labelled with product name, net/gross wt, batch no., MFG\r\ndate\r\n Total Gross Weight (Est.): ~22,500 kg | Volume: ~38 CBM\r\nQUALITY & CERTIFICATION\r\n Quality inspection by SGS India at origin before shipment\r\n Certificate of Origin (Form A / GSP) – APEDA / Chamber of\r\nCommerce\r\n Phytosanitary Certificate – Ministry of Agriculture, India\r\n FSSAI Certificate (Food Safety)\r\n Halal Certificate (HFSAA Approved Body)\r\n Analysis Report: Moisture, Broken %, Milling degree\r\nBENEFICIARY BANK DETAILS (for LC)\r\nBank Name\r\nState Bank of India, Fort Branch, Mumbai\r\nBranch Address\r\nMumbai Main Branch, Fort, Mumbai - 400001\r\nAccount Name\r\nAgro Exports India Pvt. Ltd.\r\nAccount No.\r\n10234567890\r\nIFSC Code\r\nSBIN0000300\r\nSWIFT Code\r\nSBININBB\r\nBank Reference\r\nLC to be opened 30 days prior to shipment date\r\nTERMS & CONDITIONS\r\n1. Validity: This Purchase Order is valid until 30 June 2026. Seller must confirm acceptance within 5 working days.\r\n2. Shipment: Latest shipment date 30 June 2026. Bill of Lading dated after this date will not be accepted.\r\n3. Documents Required: Signed Commercial Invoice (3 originals), Packing List, Full Set 3/3 OBL, Certificate of Origin, Phytosanitary Certificate, SGS\r\nPre-shipment Inspection Certificate, Halal Certificate, Analysis Report.\r\n4. LC Terms: Buyer will open an Irrevocable LC at Sight within 7 working days of PO acceptance. LC charges outside India are to Buyer's account.\r\n5. Insurance: Seller to arrange marine insurance for 110% of CIF value (Institute Cargo Clauses A).\r\n6. Rejection: Buyer reserves the right to reject goods not conforming to specifications. Rejected goods to be replaced at Seller's cost.\r\n7. Force Majeure: Neither party liable for delays due to natural calamity, war, government restriction, or any event beyond reasonable control.\r\n8. Governing Law: This contract shall be governed by ICC Rules. Disputes to be settled by arbitration in Dubai, UAE.\r\nFOR AL NOOR FOODSTUFF TRADING LLC\r\n_______________________________\r\nAuthorised Signatory\r\nName: Mr. Ahmed Al Rashidi\r\nDesignation: Procurement Manager\r\nDate: _____________\r\nFOR AGRO EXPORTS INDIA PVT. LTD.\r\n_______________________________\r\nAuthorised Signatory\r\nName: Ms. Priya Sharma\r\nDesignation: Director – Exports\r\nDate: _____________\r\nThis is a computer-generated Purchase Order. | Document ID: AEIPL-PO-2026-0542 | Generated: 15-May-2026 | For queries: exports@agroexportsindia.com	\N	861458b2-05a9-4e22-82ce-8e14614c655b	\N	\N	2026-05-26 14:38:37.855396+00	2026-05-26 14:38:37.855396+00
50c71ab2-119d-49c5-aceb-57793b817563	00000000-0000-0000-0000-000000000001	WA-F46C42A3	411e1cc1-b9d1-458c-baee-90da924cce16	awaiting_approval	USD	\N	LC	CIF	\N	Jebel Ali Port	IN	whatsapp	\N	\N	f46c42a3-0dc2-47aa-95d9-babbaf9ec983	\N	\N	2026-05-27 03:21:07.833704+00	2026-05-27 03:21:07.833704+00
c644e07a-56ba-4a7b-963a-fc334c7384aa	00000000-0000-0000-0000-000000000001	WA-E9EF93F8	229b7106-3743-4b74-a2b4-6a91b23db4db	awaiting_approval	USD	\N	LC	CIF	\N	Jebel Ali Port	IN	whatsapp	\N	\N	e9ef93f8-b72f-4bd9-8722-de8458107f96	\N	\N	2026-05-27 04:48:23.490691+00	2026-05-27 04:48:23.490691+00
97c24140-a8a5-4c28-b421-67a45b7b3895	00000000-0000-0000-0000-000000000001	WA-240C464A	1b2aa3c3-df1a-4e80-808a-7c5484a58308	awaiting_approval	USD	\N	LC	CIF	\N	Jebel Ali Port	IN	whatsapp	\N	\N	240c464a-825a-4b00-a426-ee9e1f9d8329	\N	\N	2026-05-27 04:49:32.773927+00	2026-05-27 04:49:32.773927+00
09919ecf-a938-4713-a1e6-80d3a6f94ce0	00000000-0000-0000-0000-000000000001	WA-21FEFA83	7c0de00f-66c5-4718-a17b-bd656905f49e	awaiting_approval	USD	\N	Letter of Credit (LC)	CIF – Jebel Ali Port, Dubai (UAE)	\N	Jebel Ali Port	IN	whatsapp	\N	\N	21fefa83-b1bf-43a3-b0d8-03dec8de4bed	\N	\N	2026-05-27 06:29:11.783371+00	2026-05-27 06:29:11.783371+00
d79747df-ae1f-42d6-ade7-4328ccfd1527	00000000-0000-0000-0000-000000000001	WA-3B1397CA	080f7840-73dd-4269-8afb-76756f23eb23	documents_pending	USD	\N	Letter of Credit	CIF	\N	Jebel Ali Port, Dubai, UAE	AE	whatsapp	\N	\N	3b1397ca-8f33-458d-bbd9-eb7dd0498fcf	\N	\N	2026-05-29 06:07:41.012168+00	2026-05-29 06:07:41.012168+00
22c3790e-999d-41a4-a9f6-a3154ce1f5cc	5359c3a9-2913-48b8-888c-00fbfd84682f	WA-6207F055	b5166f9a-6501-4ecd-90ee-b2b6d9b066b9	awaiting_approval	USD	\N	Irrevocable LC at Sight (SWIFT MT700)	CIF – Jebel Ali Port, Dubai (UAE)	\N	Jebel Ali Port	AE	portal	AGRO EXPORTS INDIA PVT. LTD. IEC: AABCA1234C    GSTIN: 27AABCA1234C1Z5\r\n123, Nariman Point, Mumbai - 400021, Maharashtra, India\r\nTel: +91-22-4567-8900   Email: exports@agroexportsindia.com\r\n Web: www.agroexportsindia.com\r\n \r\nPURCHASE ORDERPO Number:\r\nAEIPL/PO/2026/0542\r\nPO Date:\r\n15 May 2026\r\nValid Until:\r\n30 June 2026\r\nIncoterms:\r\nCIF – Jebel Ali Port, Dubai (UAE)\r\nCurrency:\r\nUSD (United States Dollar)\r\nBUYER (Importer)\r\nAL NOOR FOODSTUFF TRADING LLC\r\nP.O. Box 47823, Deira, Dubai, United Arab Emirates\r\nTRN (VAT): 100358291200003\r\nContact: Mr. Ahmed Al Rashidi\r\nTel: +971-4-226-8800  |  Email: procurement@alnoorfoods.ae\r\nSELLER (Exporter)\r\nAGRO EXPORTS INDIA PVT. LTD.\r\n123, Nariman Point, Mumbai - 400021, India\r\nIEC: AABCA1234C  |  GSTIN: 27AABCA1234C1Z5\r\nContact: Ms. Priya Sharma\r\nTel: +91-22-4567-8901  |  Email:\r\npriya.sharma@agroexportsindia.com\r\nSHIPMENT & PAYMENT DETAILS\r\nPort of Loading\r\nNhava Sheva (JNPT), Mumbai, India\r\nPayment Terms\r\nIrrevocable LC at Sight (SWIFT MT700)\r\nPort of Discharge\r\nJebel Ali Port, Dubai, UAE\r\nLC Issuing Bank\r\nEmirates NBD, Dubai (SWIFT: EBILAEAD)\r\nMode of Transport\r\nSea Freight – Full Container Load (FCL)\r\nLC Validity\r\n60 days from shipment date\r\nShipment By\r\n30 June 2026 (latest)\r\nPartial Shipment\r\nNot Allowed\r\nContainer Type\r\n1 x 20' GP Container\r\nTranshipment\r\nNot Allowed\r\nORDER LINE ITEMS\r\nSr.\r\nProduct Description\r\nHS Code\r\nQty\r\n(MT)\r\nUnit\r\nPrice (US\r\nD/MT)\r\nAmount\r\n(USD)\r\nCountry of\r\nOrigin\r\n1\r\nBasmati Rice – Grade A Extra Long Grain\r\n(1121 Variety, Aged 2 Years, Sortex Cleaned)\r\nPacking: 25 kg PP Woven Bags\r\n1006.30.2\r\n0\r\n10.0\r\n1,200.00\r\n12,000.00\r\nIndia\r\n2\r\nBasmati Rice – Grade B Long Grain (Pusa\r\n1121, Non-Aged) Packing: 50 kg Jute Bags\r\n1006.30.2\r\n0\r\n5.0\r\n980.00\r\n4,900.00\r\nIndia\r\n3\r\nBroken Basmati Rice (5% Brokens) Packing:\r\n25 kg PP Woven Bags\r\n1006.40.0\r\n0\r\n3.0\r\n620.00\r\n1,860.00\r\nIndia\r\n4\r\nRice Bran Oil – Refined (Edible Grade, 15 kg\r\nTins) Certification: FSSAI & Halal\r\n1514.19.0\r\n0\r\n2.0\r\n1,450.00\r\n2,900.00\r\nIndia\r\nSub-Total (FOB Mumbai)\r\n20 MT\r\n21,660.00\r\nSea Freight (Mumbai → Jebel Ali)\r\n1,200.00\r\nMarine Insurance (0.15% of CIF)\r\n325.00\r\nGRAND TOTAL (CIF Jebel Ali)\r\nUSD 23,1\r\n85.00\r\n\r\nPACKING SPECIFICATIONS\r\n Item 1: 400 bags x 25 kg PP Woven (heat-sealed, double-stitched)\r\n Item 2: 100 bags x 50 kg Food-Grade Jute Bags\r\n Item 3: 120 bags x 25 kg PP Woven Bags\r\n Item 4: 133 tins x 15 kg (food-grade tins, sealed)\r\n All bags: labelled with product name, net/gross wt, batch no., MFG\r\ndate\r\n Total Gross Weight (Est.): ~22,500 kg | Volume: ~38 CBM\r\nQUALITY & CERTIFICATION\r\n Quality inspection by SGS India at origin before shipment\r\n Certificate of Origin (Form A / GSP) – APEDA / Chamber of\r\nCommerce\r\n Phytosanitary Certificate – Ministry of Agriculture, India\r\n FSSAI Certificate (Food Safety)\r\n Halal Certificate (HFSAA Approved Body)\r\n Analysis Report: Moisture, Broken %, Milling degree\r\nBENEFICIARY BANK DETAILS (for LC)\r\nBank Name\r\nState Bank of India, Fort Branch, Mumbai\r\nBranch Address\r\nMumbai Main Branch, Fort, Mumbai - 400001\r\nAccount Name\r\nAgro Exports India Pvt. Ltd.\r\nAccount No.\r\n10234567890\r\nIFSC Code\r\nSBIN0000300\r\nSWIFT Code\r\nSBININBB\r\nBank Reference\r\nLC to be opened 30 days prior to shipment date\r\nTERMS & CONDITIONS\r\n1. Validity: This Purchase Order is valid until 30 June 2026. Seller must confirm acceptance within 5 working days.\r\n2. Shipment: Latest shipment date 30 June 2026. Bill of Lading dated after this date will not be accepted.\r\n3. Documents Required: Signed Commercial Invoice (3 originals), Packing List, Full Set 3/3 OBL, Certificate of Origin, Phytosanitary Certificate, SGS\r\nPre-shipment Inspection Certificate, Halal Certificate, Analysis Report.\r\n4. LC Terms: Buyer will open an Irrevocable LC at Sight within 7 working days of PO acceptance. LC charges outside India are to Buyer's account.\r\n5. Insurance: Seller to arrange marine insurance for 110% of CIF value (Institute Cargo Clauses A).\r\n6. Rejection: Buyer reserves the right to reject goods not conforming to specifications. Rejected goods to be replaced at Seller's cost.\r\n7. Force Majeure: Neither party liable for delays due to natural calamity, war, government restriction, or any event beyond reasonable control.\r\n8. Governing Law: This contract shall be governed by ICC Rules. Disputes to be settled by arbitration in Dubai, UAE.\r\nFOR AL NOOR FOODSTUFF TRADING LLC\r\n_______________________________\r\nAuthorised Signatory\r\nName: Mr. Ahmed Al Rashidi\r\nDesignation: Procurement Manager\r\nDate: _____________\r\nFOR AGRO EXPORTS INDIA PVT. LTD.\r\n_______________________________\r\nAuthorised Signatory\r\nName: Ms. Priya Sharma\r\nDesignation: Director – Exports\r\nDate: _____________\r\nThis is a computer-generated Purchase Order. | Document ID: AEIPL-PO-2026-0542 | Generated: 15-May-2026 | For queries: exports@agroexportsindia.com	\N	6207f055-1ad7-4ddf-9b34-6cf4b2610286	\N	\N	2026-05-29 12:51:40.841153+00	2026-05-29 12:51:40.841153+00
c25512a9-b11d-4445-9eec-f9538b729af3	841689d4-2d6a-4391-b453-930e6fbb35a5	WA-110DBE43	ddda41f1-a7fb-4470-9cef-174d7cb99c6f	documents_pending	USD	\N	Letter of Credit	CIF	\N	Jebel Ali Port, Dubai, UAE	AE	portal	PURCHASE ORDER\r\nSELLER (Exporter)  AGRO EXPORTS INDIA PVT. LTD. \r\n123, Nariman Point, Mumbai - 400021, Maharashtra, India \r\nIEC: AABCA1234C | GSTIN: 27AABCA1234C1Z5 \r\nContact: Ms. Priya Sharma (Director - Exports) \r\nTel: +91-22-4567-8901 | Email: priya.sharma@agroexportsindia.com \r\nBUYER (Importer)  DHIRAJ GROUP 456 Business Avenue, Business Bay, Dubai, \r\nUnited Arab Emirates\r\nTRN (VAT): 100293847563\r\nPO OVERVIEW\r\nPO Number: AEIPL/PO/2026/0542 \r\nPO Date: 15 May 2026 \r\nValid Until: 30 June 2026 \r\nIncoterms:CIF - Jebel Ali Port, Dubai \r\n(UAE)\r\nCurrency: USD (United States Dollar) \r\nLUT/Bond \r\nNumber:LUT-2026-98765\r\nSHIPMENT & PAYMENT DETAILS\r\nPort of LoadingNhava Sheva (JNPT), \r\nMumbai, IndiaPayment \r\nTermsLetter of Credit \r\n(LC)\r\nPort of \r\nDischargeJebel Ali Port, Dubai, UAE LC Number LC-987654321\r\nPre-Carriage By Road TransportLC Issuing \r\nBankEmirates NBD \r\nDubai\r\nMode of \r\nTransportOcean FreightLC Expiry \r\nDate31 December \r\n2026\r\nExpected \r\nDelivery15 November 2026 Partial \r\nShipmentNot Allowed \r\nDestination \r\nCountryUnited Arab EmiratesTranshipmen\r\ntNot Allowed \r\nORDER LINE ITEMS\r\nS\r\nr\r\n.Product \r\nDescriptionHS \r\nCodeQt\r\nyUnit \r\nPrice \r\n(USD)Total \r\nAmount \r\n(USD)Country \r\nof Origin\r\n1Dell Latitude 7420  \r\nLaptops\r\nArabic:   كمبيوترمحمول \r\n  ديللاتيتيود 7420847130\r\n1010\r\n0 \r\nPC\r\nS300.0030,000.00USA\r\nSUB-TOTAL10\r\n0 \r\nPC\r\nS30,000.00\r\nSea Freight & \r\nInsuranceIncluded \r\n(CIF)\r\nGRAND TOTALUSD \r\n30,000.00\r\nPACKING SPECIFICATIONS\r\n•Packaging Type:  Standard Export Packaging. Laptops are properly packaged and \r\nmarked for export.\r\n•Configuration: 100 Laptops packed in 10 master cartons (10 laptops per carton).\r\n•Carton Dimensions:  $50\\text{cm} \\times 40\\text{cm} \\times 30\\text{cm}$ .\r\n•Weight Metrics:  * Net Weight per Carton:  13 kg\r\n•Gross Weight per Carton:  15.5 kg\r\n•Total Net Weight:  130 kg\r\n•Total Gross Weight:  155 kg\r\n•Labelling: All cartons must be clearly labelled with product name, net/gross weight, \r\nbatch/serial numbers, and country of origin.\r\nBENEFICIARY BANK DETAILS\r\nBank Name State Bank of India, Fort Branch, Mumbai \r\nBranch Mumbai Main Branch, Fort, Mumbai \r\nAddress 400001 \r\nAccount \r\nNameAgro Exports India Pvt. Ltd. \r\nAccount No. 10234567890 \r\nIFSC Code SBIN0000300 \r\nSWIFT Code SBININBB \r\nTERMS & CONDITIONS\r\n1.Acceptance: Seller must confirm acceptance of this updated purchase order within 5 \r\nworking days. \r\n2.Documentation:  The following original documents are required for customs \r\nclearance: Signed Commercial Invoice (3 originals), Packing List, Full Set 3/3 Original \r\nBill of Lading (OBL), Certificate of Origin, and Quality/Inspection Certificates.  \r\n3.Insurance: Marine insurance is to be covered by the Seller for 110% of the CIF value \r\nunder Institute Cargo Clauses (A).  \r\n4.Governing Law:  This contract shall be governed by ICC Rules. Any disputes that \r\ncannot be settled amicably shall be resolved by arbitration in Dubai, UAE.  \r\nFOR DHIRAJ GROUP  ___________________________\r\nAuthorised Signatory  Date:\r\nFOR AGRO EXPORTS INDIA PVT. LTD. \r\nAuthorised Signatory  \r\nName: Ms. Priya Sharma \r\nDesignation: Director - Exports \r\nDate: 20th May 2026	\N	110dbe43-e6cb-4506-8212-659f5cf5b9f6	\N	\N	2026-05-30 01:37:58.801808+00	2026-05-30 01:37:58.801808+00
376ab6e7-f7ca-4cb0-99bd-83e09ad15d8e	005d0831-36c7-4d44-bb52-6d9a13bacb4d	WA-32268EF0	5599f9eb-4f95-4563-a159-e2713571859d	awaiting_approval	USD	\N	Irrevocable LC at Sight (SWIFT MT700)	CIF – Jebel Ali Port, Dubai (UAE)	\N	Jebel Ali Port	AE	portal	AGRO EXPORTS INDIA PVT. LTD. IEC: AABCA1234C    GSTIN: 27AABCA1234C1Z5\r\n123, Nariman Point, Mumbai - 400021, Maharashtra, India\r\nTel: +91-22-4567-8900   Email: exports@agroexportsindia.com\r\n Web: www.agroexportsindia.com\r\n \r\nPURCHASE ORDERPO Number:\r\nAEIPL/PO/2026/0542\r\nPO Date:\r\n15 May 2026\r\nValid Until:\r\n30 June 2026\r\nIncoterms:\r\nCIF – Jebel Ali Port, Dubai (UAE)\r\nCurrency:\r\nUSD (United States Dollar)\r\nBUYER (Importer)\r\nAL NOOR FOODSTUFF TRADING LLC\r\nP.O. Box 47823, Deira, Dubai, United Arab Emirates\r\nTRN (VAT): 100358291200003\r\nContact: Mr. Ahmed Al Rashidi\r\nTel: +971-4-226-8800  |  Email: procurement@alnoorfoods.ae\r\nSELLER (Exporter)\r\nAGRO EXPORTS INDIA PVT. LTD.\r\n123, Nariman Point, Mumbai - 400021, India\r\nIEC: AABCA1234C  |  GSTIN: 27AABCA1234C1Z5\r\nContact: Ms. Priya Sharma\r\nTel: +91-22-4567-8901  |  Email:\r\npriya.sharma@agroexportsindia.com\r\nSHIPMENT & PAYMENT DETAILS\r\nPort of Loading\r\nNhava Sheva (JNPT), Mumbai, India\r\nPayment Terms\r\nIrrevocable LC at Sight (SWIFT MT700)\r\nPort of Discharge\r\nJebel Ali Port, Dubai, UAE\r\nLC Issuing Bank\r\nEmirates NBD, Dubai (SWIFT: EBILAEAD)\r\nMode of Transport\r\nSea Freight – Full Container Load (FCL)\r\nLC Validity\r\n60 days from shipment date\r\nShipment By\r\n30 June 2026 (latest)\r\nPartial Shipment\r\nNot Allowed\r\nContainer Type\r\n1 x 20' GP Container\r\nTranshipment\r\nNot Allowed\r\nORDER LINE ITEMS\r\nSr.\r\nProduct Description\r\nHS Code\r\nQty\r\n(MT)\r\nUnit\r\nPrice (US\r\nD/MT)\r\nAmount\r\n(USD)\r\nCountry of\r\nOrigin\r\n1\r\nBasmati Rice – Grade A Extra Long Grain\r\n(1121 Variety, Aged 2 Years, Sortex Cleaned)\r\nPacking: 25 kg PP Woven Bags\r\n1006.30.2\r\n0\r\n10.0\r\n1,200.00\r\n12,000.00\r\nIndia\r\n2\r\nBasmati Rice – Grade B Long Grain (Pusa\r\n1121, Non-Aged) Packing: 50 kg Jute Bags\r\n1006.30.2\r\n0\r\n5.0\r\n980.00\r\n4,900.00\r\nIndia\r\n3\r\nBroken Basmati Rice (5% Brokens) Packing:\r\n25 kg PP Woven Bags\r\n1006.40.0\r\n0\r\n3.0\r\n620.00\r\n1,860.00\r\nIndia\r\n4\r\nRice Bran Oil – Refined (Edible Grade, 15 kg\r\nTins) Certification: FSSAI & Halal\r\n1514.19.0\r\n0\r\n2.0\r\n1,450.00\r\n2,900.00\r\nIndia\r\nSub-Total (FOB Mumbai)\r\n20 MT\r\n21,660.00\r\nSea Freight (Mumbai → Jebel Ali)\r\n1,200.00\r\nMarine Insurance (0.15% of CIF)\r\n325.00\r\nGRAND TOTAL (CIF Jebel Ali)\r\nUSD 23,1\r\n85.00\r\n\r\nPACKING SPECIFICATIONS\r\n Item 1: 400 bags x 25 kg PP Woven (heat-sealed, double-stitched)\r\n Item 2: 100 bags x 50 kg Food-Grade Jute Bags\r\n Item 3: 120 bags x 25 kg PP Woven Bags\r\n Item 4: 133 tins x 15 kg (food-grade tins, sealed)\r\n All bags: labelled with product name, net/gross wt, batch no., MFG\r\ndate\r\n Total Gross Weight (Est.): ~22,500 kg | Volume: ~38 CBM\r\nQUALITY & CERTIFICATION\r\n Quality inspection by SGS India at origin before shipment\r\n Certificate of Origin (Form A / GSP) – APEDA / Chamber of\r\nCommerce\r\n Phytosanitary Certificate – Ministry of Agriculture, India\r\n FSSAI Certificate (Food Safety)\r\n Halal Certificate (HFSAA Approved Body)\r\n Analysis Report: Moisture, Broken %, Milling degree\r\nBENEFICIARY BANK DETAILS (for LC)\r\nBank Name\r\nState Bank of India, Fort Branch, Mumbai\r\nBranch Address\r\nMumbai Main Branch, Fort, Mumbai - 400001\r\nAccount Name\r\nAgro Exports India Pvt. Ltd.\r\nAccount No.\r\n10234567890\r\nIFSC Code\r\nSBIN0000300\r\nSWIFT Code\r\nSBININBB\r\nBank Reference\r\nLC to be opened 30 days prior to shipment date\r\nTERMS & CONDITIONS\r\n1. Validity: This Purchase Order is valid until 30 June 2026. Seller must confirm acceptance within 5 working days.\r\n2. Shipment: Latest shipment date 30 June 2026. Bill of Lading dated after this date will not be accepted.\r\n3. Documents Required: Signed Commercial Invoice (3 originals), Packing List, Full Set 3/3 OBL, Certificate of Origin, Phytosanitary Certificate, SGS\r\nPre-shipment Inspection Certificate, Halal Certificate, Analysis Report.\r\n4. LC Terms: Buyer will open an Irrevocable LC at Sight within 7 working days of PO acceptance. LC charges outside India are to Buyer's account.\r\n5. Insurance: Seller to arrange marine insurance for 110% of CIF value (Institute Cargo Clauses A).\r\n6. Rejection: Buyer reserves the right to reject goods not conforming to specifications. Rejected goods to be replaced at Seller's cost.\r\n7. Force Majeure: Neither party liable for delays due to natural calamity, war, government restriction, or any event beyond reasonable control.\r\n8. Governing Law: This contract shall be governed by ICC Rules. Disputes to be settled by arbitration in Dubai, UAE.\r\nFOR AL NOOR FOODSTUFF TRADING LLC\r\n_______________________________\r\nAuthorised Signatory\r\nName: Mr. Ahmed Al Rashidi\r\nDesignation: Procurement Manager\r\nDate: _____________\r\nFOR AGRO EXPORTS INDIA PVT. LTD.\r\n_______________________________\r\nAuthorised Signatory\r\nName: Ms. Priya Sharma\r\nDesignation: Director – Exports\r\nDate: _____________\r\nThis is a computer-generated Purchase Order. | Document ID: AEIPL-PO-2026-0542 | Generated: 15-May-2026 | For queries: exports@agroexportsindia.com	\N	32268ef0-d5ed-49b5-8877-2f5c9f5df5bc	\N	\N	2026-05-30 13:48:30.520316+00	2026-05-30 13:48:30.520316+00
def36f34-5ee0-4759-bbe3-b4d6f95c31bb	07ab628b-6aa2-47e9-9893-fbdd583a7cba	WA-866C5538	381591d5-6439-4ac4-8be9-e2a16d556918	documents_pending	USD	\N	Irrevocable LC at Sight (SWIFT MT700)	CIF – Jebel Ali Port, Dubai (UAE)	\N	Jebel Ali Port	AE	portal	AGRO EXPORTS INDIA PVT. LTD. IEC: AABCA1234C    GSTIN: 27AABCA1234C1Z5\r\n123, Nariman Point, Mumbai - 400021, Maharashtra, India\r\nTel: +91-22-4567-8900   Email: exports@agroexportsindia.com\r\n Web: www.agroexportsindia.com\r\n \r\nPURCHASE ORDERPO Number:\r\nAEIPL/PO/2026/0542\r\nPO Date:\r\n15 May 2026\r\nValid Until:\r\n30 June 2026\r\nIncoterms:\r\nCIF – Jebel Ali Port, Dubai (UAE)\r\nCurrency:\r\nUSD (United States Dollar)\r\nBUYER (Importer)\r\nAL NOOR FOODSTUFF TRADING LLC\r\nP.O. Box 47823, Deira, Dubai, United Arab Emirates\r\nTRN (VAT): 100358291200003\r\nContact: Mr. Ahmed Al Rashidi\r\nTel: +971-4-226-8800  |  Email: procurement@alnoorfoods.ae\r\nSELLER (Exporter)\r\nAGRO EXPORTS INDIA PVT. LTD.\r\n123, Nariman Point, Mumbai - 400021, India\r\nIEC: AABCA1234C  |  GSTIN: 27AABCA1234C1Z5\r\nContact: Ms. Priya Sharma\r\nTel: +91-22-4567-8901  |  Email:\r\npriya.sharma@agroexportsindia.com\r\nSHIPMENT & PAYMENT DETAILS\r\nPort of Loading\r\nNhava Sheva (JNPT), Mumbai, India\r\nPayment Terms\r\nIrrevocable LC at Sight (SWIFT MT700)\r\nPort of Discharge\r\nJebel Ali Port, Dubai, UAE\r\nLC Issuing Bank\r\nEmirates NBD, Dubai (SWIFT: EBILAEAD)\r\nMode of Transport\r\nSea Freight – Full Container Load (FCL)\r\nLC Validity\r\n60 days from shipment date\r\nShipment By\r\n30 June 2026 (latest)\r\nPartial Shipment\r\nNot Allowed\r\nContainer Type\r\n1 x 20' GP Container\r\nTranshipment\r\nNot Allowed\r\nORDER LINE ITEMS\r\nSr.\r\nProduct Description\r\nHS Code\r\nQty\r\n(MT)\r\nUnit\r\nPrice (US\r\nD/MT)\r\nAmount\r\n(USD)\r\nCountry of\r\nOrigin\r\n1\r\nBasmati Rice – Grade A Extra Long Grain\r\n(1121 Variety, Aged 2 Years, Sortex Cleaned)\r\nPacking: 25 kg PP Woven Bags\r\n1006.30.2\r\n0\r\n10.0\r\n1,200.00\r\n12,000.00\r\nIndia\r\n2\r\nBasmati Rice – Grade B Long Grain (Pusa\r\n1121, Non-Aged) Packing: 50 kg Jute Bags\r\n1006.30.2\r\n0\r\n5.0\r\n980.00\r\n4,900.00\r\nIndia\r\n3\r\nBroken Basmati Rice (5% Brokens) Packing:\r\n25 kg PP Woven Bags\r\n1006.40.0\r\n0\r\n3.0\r\n620.00\r\n1,860.00\r\nIndia\r\n4\r\nRice Bran Oil – Refined (Edible Grade, 15 kg\r\nTins) Certification: FSSAI & Halal\r\n1514.19.0\r\n0\r\n2.0\r\n1,450.00\r\n2,900.00\r\nIndia\r\nSub-Total (FOB Mumbai)\r\n20 MT\r\n21,660.00\r\nSea Freight (Mumbai → Jebel Ali)\r\n1,200.00\r\nMarine Insurance (0.15% of CIF)\r\n325.00\r\nGRAND TOTAL (CIF Jebel Ali)\r\nUSD 23,1\r\n85.00\r\n\r\nPACKING SPECIFICATIONS\r\n Item 1: 400 bags x 25 kg PP Woven (heat-sealed, double-stitched)\r\n Item 2: 100 bags x 50 kg Food-Grade Jute Bags\r\n Item 3: 120 bags x 25 kg PP Woven Bags\r\n Item 4: 133 tins x 15 kg (food-grade tins, sealed)\r\n All bags: labelled with product name, net/gross wt, batch no., MFG\r\ndate\r\n Total Gross Weight (Est.): ~22,500 kg | Volume: ~38 CBM\r\nQUALITY & CERTIFICATION\r\n Quality inspection by SGS India at origin before shipment\r\n Certificate of Origin (Form A / GSP) – APEDA / Chamber of\r\nCommerce\r\n Phytosanitary Certificate – Ministry of Agriculture, India\r\n FSSAI Certificate (Food Safety)\r\n Halal Certificate (HFSAA Approved Body)\r\n Analysis Report: Moisture, Broken %, Milling degree\r\nBENEFICIARY BANK DETAILS (for LC)\r\nBank Name\r\nState Bank of India, Fort Branch, Mumbai\r\nBranch Address\r\nMumbai Main Branch, Fort, Mumbai - 400001\r\nAccount Name\r\nAgro Exports India Pvt. Ltd.\r\nAccount No.\r\n10234567890\r\nIFSC Code\r\nSBIN0000300\r\nSWIFT Code\r\nSBININBB\r\nBank Reference\r\nLC to be opened 30 days prior to shipment date\r\nTERMS & CONDITIONS\r\n1. Validity: This Purchase Order is valid until 30 June 2026. Seller must confirm acceptance within 5 working days.\r\n2. Shipment: Latest shipment date 30 June 2026. Bill of Lading dated after this date will not be accepted.\r\n3. Documents Required: Signed Commercial Invoice (3 originals), Packing List, Full Set 3/3 OBL, Certificate of Origin, Phytosanitary Certificate, SGS\r\nPre-shipment Inspection Certificate, Halal Certificate, Analysis Report.\r\n4. LC Terms: Buyer will open an Irrevocable LC at Sight within 7 working days of PO acceptance. LC charges outside India are to Buyer's account.\r\n5. Insurance: Seller to arrange marine insurance for 110% of CIF value (Institute Cargo Clauses A).\r\n6. Rejection: Buyer reserves the right to reject goods not conforming to specifications. Rejected goods to be replaced at Seller's cost.\r\n7. Force Majeure: Neither party liable for delays due to natural calamity, war, government restriction, or any event beyond reasonable control.\r\n8. Governing Law: This contract shall be governed by ICC Rules. Disputes to be settled by arbitration in Dubai, UAE.\r\nFOR AL NOOR FOODSTUFF TRADING LLC\r\n_______________________________\r\nAuthorised Signatory\r\nName: Mr. Ahmed Al Rashidi\r\nDesignation: Procurement Manager\r\nDate: _____________\r\nFOR AGRO EXPORTS INDIA PVT. LTD.\r\n_______________________________\r\nAuthorised Signatory\r\nName: Ms. Priya Sharma\r\nDesignation: Director – Exports\r\nDate: _____________\r\nThis is a computer-generated Purchase Order. | Document ID: AEIPL-PO-2026-0542 | Generated: 15-May-2026 | For queries: exports@agroexportsindia.com	\N	866c5538-1881-40ad-9706-35eddd61c7c6	\N	\N	2026-06-04 11:24:36.040003+00	2026-06-04 11:24:36.040003+00
\.


--
-- Data for Name: organizations; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.organizations (id, name, slug, country, iec_code, gstin, vat_number, plan, timezone, default_currency, whatsapp_number, smtp_config, is_active, created_at, updated_at, extraction_rules, rules_bundle_version, rules_bundle_synced_at) FROM stdin;
00000000-0000-0000-0000-000000000001	Agro Exports India Pvt Ltd	agro-exports-india	IN	\N	\N	\N	growth	Asia/Kolkata	INR	\N	\N	t	2026-05-22 11:40:48.183464+00	2026-05-22 11:40:48.183464+00	{}	0.0.0	\N
a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11	TradeOS Demo Corp	tradeos-demo-corp	IN	\N	\N	\N	growth	Asia/Kolkata	USD	\N	\N	t	2026-05-23 07:17:28.079292+00	2026-05-23 07:17:28.079292+00	{}	0.0.0	\N
07ab628b-6aa2-47e9-9893-fbdd583a7cba	Demo Organization	demo-org	IN	\N	\N	\N	starter	Asia/Kolkata	INR	\N	\N	t	2026-05-25 08:15:12.75271+00	2026-05-25 08:15:12.75271+00	{}	0.0.0	\N
3401cbbd-dc58-4278-9e77-48314c1c1f9b	Test Corp 4c7129	test-corp-4c7129	IN	\N	\N	\N	starter	Asia/Kolkata	INR	\N	\N	t	2026-05-27 14:17:30.560898+00	2026-05-27 14:17:30.560898+00	{}	0.0.0	\N
9d47cec6-5f1a-48c2-8aef-2ae53c267ca7	Tanushree Patra's Organization	tanushree-patras-organization	IN	\N	\N	\N	starter	Asia/Kolkata	INR	\N	\N	t	2026-05-28 15:31:23.453005+00	2026-05-28 15:31:23.453005+00	{}	0.0.0	\N
cbdaef09-f8f4-4199-a077-116b753218bf	Tanushree Patra's Organization	tanushree-patras-organization-1	IN	\N	\N	\N	starter	Asia/Kolkata	INR	\N	\N	t	2026-05-28 15:34:40.78015+00	2026-05-28 15:34:40.78015+00	{}	0.0.0	\N
005d0831-36c7-4d44-bb52-6d9a13bacb4d	Om Patra's Organization	om-patras-organization	IN	\N	\N	\N	starter	Asia/Kolkata	INR	\N	\N	t	2026-05-29 12:47:24.963132+00	2026-05-29 12:47:24.963132+00	{}	0.0.0	\N
5359c3a9-2913-48b8-888c-00fbfd84682f	Om Patra's Organization	om-patras-organization-1	IN	\N	\N	\N	starter	Asia/Kolkata	INR	\N	\N	t	2026-05-29 12:47:43.831104+00	2026-05-29 12:47:43.831104+00	{}	0.0.0	\N
841689d4-2d6a-4391-b453-930e6fbb35a5	Dhiraj Patra's Organization	dhiraj-patras-organization	IN	\N	\N	\N	starter	Asia/Kolkata	INR	\N	\N	t	2026-05-30 01:37:04.392724+00	2026-05-30 01:37:04.392724+00	{}	0.0.0	\N
\.


--
-- Data for Name: po_templates; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.po_templates (id, org_id, buyer_key, buyer_name, buyer_country, currency, payment_terms, incoterms, destination_port, field_anchors, use_count, avg_confidence, last_extraction_confidence, llm_fallback_count, template_hit_count, last_used_at, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: products; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.products (id, org_id, sku, description, hs_code, hs_validated_at, hs_confidence, unit, default_currency, unit_price, country_of_origin, custom_fields, created_at) FROM stdin;
b1000000-0000-0000-0000-000000000001	00000000-0000-0000-0000-000000000001	RICE-BASMATI-1121-A	Basmati Rice Grade A — 1121 Extra Long Grain, Aged 2 Years	1006302000	\N	96.50	KG	USD	1.2000	IN	{}	2026-05-23 04:41:50.068651+00
b2000000-0000-0000-0000-000000000001	00000000-0000-0000-0000-000000000001	RICE-BASMATI-PUSA-B	Basmati Rice Grade B — Pusa 1121	1006302000	\N	94.00	KG	USD	0.9800	IN	{}	2026-05-23 04:41:50.068651+00
b3000000-0000-0000-0000-000000000001	00000000-0000-0000-0000-000000000001	OIL-RICE-BRAN-REF	Refined Rice Bran Oil — Edible Grade, FSSAI Certified	1514191000	\N	91.00	KG	USD	1.4500	IN	{}	2026-05-23 04:41:50.068651+00
e0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11	a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11	SKU-TXT-001	Premium Cotton T-Shirts	61091000	\N	\N	PCS	USD	15.0000	IN	{}	2026-05-23 07:17:29.358832+00
e0eebc99-9c0b-4ef8-bb6d-6bb9bd380a12	a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11	SKU-ELC-002	Wireless Earbuds	85183000	\N	\N	PCS	USD	45.0000	IN	{}	2026-05-23 07:17:29.358832+00
\.


--
-- Data for Name: prompt_registry; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.prompt_registry (id, org_id, agent_name, prompt_key, version, is_active, system_prompt, user_template, output_schema, fallback_model, fallback_prompt_id, avg_confidence, success_count, failure_count, avg_latency_ms, created_by, created_at) FROM stdin;
\.


--
-- Data for Name: shipment_events; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.shipment_events (id, shipment_id, event_code, description, location, occurred_at, source, raw_data, created_at) FROM stdin;
7841310d-3a15-4512-9c5d-9396b44471a8	e5000000-0000-0000-0000-000000000001	CARGO_RECEIVED	Cargo received at JNPT CFS	Nhava Sheva, Mumbai, India	2026-05-17 04:41:50.068651+00	carrier	\N	2026-05-23 04:41:50.068651+00
cd733ab9-e8da-4fb5-93b9-140d9c4f930e	e5000000-0000-0000-0000-000000000001	CUSTOMS_CLEARED	Export customs cleared — Shipping Bill filed	Nhava Sheva, Mumbai, India	2026-05-17 22:41:50.068651+00	customs	\N	2026-05-23 04:41:50.068651+00
197f7acf-8404-493f-a988-43d803486656	e5000000-0000-0000-0000-000000000001	LADEN_ON_VESSEL	Container laden on vessel MSC AFRICA	Nhava Sheva, Mumbai, India	2026-05-18 04:41:50.068651+00	carrier	\N	2026-05-23 04:41:50.068651+00
7db4ae31-a616-4a85-9038-a2f9c746f4c2	e5000000-0000-0000-0000-000000000001	IN_TRANSIT	Vessel en route to Jebel Ali	Arabian Sea	2026-05-18 08:41:50.068651+00	carrier	\N	2026-05-23 04:41:50.068651+00
f8ef1aaa-6825-4605-b080-bcb0898566bb	e5000000-0000-0000-0000-000000000001	ETA_UPDATE	ETA confirmed: 24 May 2026 07:00 GST	Jebel Ali Port, Dubai, UAE	2026-05-22 04:41:50.068651+00	carrier	\N	2026-05-23 04:41:50.068651+00
111ebc99-9c0b-4ef8-bb6d-6bb9bd380a11	d0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11	BKG	Booking Confirmed	Nhava Sheva, India	2026-05-13 07:17:31.405234+00	carrier	\N	2026-05-23 07:17:31.405234+00
111ebc99-9c0b-4ef8-bb6d-6bb9bd380a12	d0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11	DEP	Vessel Departed Port of Loading	Nhava Sheva, India	2026-05-18 07:17:31.405234+00	carrier	\N	2026-05-23 07:17:31.405234+00
111ebc99-9c0b-4ef8-bb6d-6bb9bd380a13	d0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11	TRS	In Transit - Passing Suez Canal	Suez, Egypt	2026-05-22 07:17:31.405234+00	carrier	\N	2026-05-23 07:17:31.405234+00
111ebc99-9c0b-4ef8-bb6d-6bb9bd380a14	d0eebc99-9c0b-4ef8-bb6d-6bb9bd380a12	RCS	Cargo Received from Shipper	Mumbai, India	2026-05-21 07:17:31.405234+00	carrier	\N	2026-05-23 07:17:31.405234+00
111ebc99-9c0b-4ef8-bb6d-6bb9bd380a15	d0eebc99-9c0b-4ef8-bb6d-6bb9bd380a12	DEP	Flight Departed	Mumbai, India	2026-05-22 07:17:31.405234+00	carrier	\N	2026-05-23 07:17:31.405234+00
\.


--
-- Data for Name: shipments; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.shipments (id, org_id, order_id, carrier, service_type, tracking_number, bl_number, awb_number, container_number, vessel_name, voyage_number, port_of_loading, port_of_discharge, etd, eta, actual_departure, actual_arrival, status, last_event, last_event_at, carrier_raw_response, created_at, updated_at) FROM stdin;
e5000000-0000-0000-0000-000000000001	00000000-0000-0000-0000-000000000001	a1000000-0000-0000-0000-000000000004	Mediterranean Shipping Company (MSC)	sea	MSCU2026748291	MSCU2026748291	\N	MSCU4421873	MSC AFRICA	2604E	Nhava Sheva (JNPT), Mumbai, India	Jebel Ali Port, Dubai, UAE	2026-05-18	2026-05-24	\N	\N	in_transit	Vessel departed JNPT — ETA Jebel Ali 24 May 2026	2026-05-18 08:41:50.068651+00	\N	2026-05-23 04:41:50.068651+00	2026-05-23 04:41:50.068651+00
d0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11	a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11	c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11	Maersk	sea	TRK-MSK-9901	BL-MSK-202605A	\N	\N	\N	\N	INNSA	USNYC	2026-05-18	2026-06-17	\N	\N	in_transit	\N	\N	\N	2026-05-23 07:17:30.896207+00	2026-05-23 07:17:30.896207+00
d0eebc99-9c0b-4ef8-bb6d-6bb9bd380a12	a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11	c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a12	DHL Aviation	air	AWB-DHL-8802	\N	AWB-DHL-202605B	\N	\N	\N	INBOM	GBHDR	2026-05-22	2026-05-25	\N	\N	in_transit	\N	\N	\N	2026-05-23 07:17:30.896207+00	2026-05-23 07:17:30.896207+00
ce740aef-b9ec-4a2a-ba16-054ca5e3b334	00000000-0000-0000-0000-000000000001	08db030b-52c2-4bf6-9ef0-55ba90735339	\N	\N	\N	\N	\N	\N	\N	\N	Nhava Sheva (JNPT), Mumbai, India	Jebel Ali Port, Dubai, UAE	\N	\N	\N	\N	booking_pending	\N	\N	\N	2026-05-23 10:52:55.702629+00	2026-05-23 10:52:55.702629+00
18db7411-207f-4523-b480-45f7801d2bdb	00000000-0000-0000-0000-000000000001	4a1cf358-2549-45c4-a1e5-dab409948f7c	\N	\N	\N	\N	\N	\N	\N	\N	Nhava Sheva, Mumbai, India	Jebel Ali Port, Dubai	\N	\N	\N	\N	booking_pending	\N	\N	\N	2026-05-23 15:58:27.400923+00	2026-05-23 15:58:27.400923+00
fbad2384-b3ac-49e4-a302-db0b4ab6774a	00000000-0000-0000-0000-000000000001	d79747df-ae1f-42d6-ade7-4328ccfd1527	\N	\N	\N	\N	\N	\N	\N	\N	Nhava Sheva (JNPT), Mumbai, India	Jebel Ali Port, Dubai, UAE	\N	\N	\N	\N	booking_pending	\N	\N	\N	2026-05-29 06:07:41.695425+00	2026-05-29 06:07:41.695425+00
2b3341eb-81b3-4778-ab53-9643f61d8cfe	841689d4-2d6a-4391-b453-930e6fbb35a5	c25512a9-b11d-4445-9eec-f9538b729af3	\N	\N	\N	\N	\N	\N	\N	\N	Nhava Sheva (JNPT), Mumbai, India	Jebel Ali Port, Dubai, UAE	\N	\N	\N	\N	booking_pending	\N	\N	\N	2026-05-30 01:37:58.818812+00	2026-05-30 01:37:58.818812+00
5cfb9dcd-9cd3-4a64-8e76-79bbc565bd92	07ab628b-6aa2-47e9-9893-fbdd583a7cba	def36f34-5ee0-4759-bbe3-b4d6f95c31bb	\N	\N	\N	\N	\N	\N	\N	\N	Nhava Sheva (JNPT), Mumbai, India	Jebel Ali Port	\N	\N	\N	\N	booking_pending	\N	\N	\N	2026-06-04 11:24:36.064756+00	2026-06-04 11:24:36.064756+00
\.


--
-- Data for Name: user_sessions; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.user_sessions (id, user_id, org_id, token, ip_address, user_agent, is_active, expires_at, created_at, updated_at) FROM stdin;
95f6ade7-7c54-4b83-8abe-1712ac8dc795	2beeb91b-32b2-4541-9dac-0439818f7d1d	3401cbbd-dc58-4278-9e77-48314c1c1f9b	1f7829758d507a1d95ceed3acb8894248f13dffde7bb00b21ccb2fa5d5f4102d	\N	\N	t	2026-05-28 08:47:32.060521+00	2026-05-27 14:17:30.560898+00	2026-05-27 14:17:30.560898+00
e76f56d0-57f5-4dd8-9590-9decb4aee13c	2beeb91b-32b2-4541-9dac-0439818f7d1d	3401cbbd-dc58-4278-9e77-48314c1c1f9b	59f32f23ac672bc9bccb5beaa3c997fcd4cdfa383ebdb06879e0017febd64b3e	\N	\N	f	2026-05-28 08:47:34.620021+00	2026-05-27 14:17:34.788915+00	2026-05-27 14:17:38.379019+00
492a7ba9-ab51-46ff-8b2b-1cf2b9676f53	e4039479-cd41-4e84-829b-f6ca55a3a1d5	9d47cec6-5f1a-48c2-8aef-2ae53c267ca7	12473d16f73d8111fa00d856b023b01a5e203582e9c0027edcf28a399ab24027	\N	\N	t	2026-05-29 15:31:23.493634+00	2026-05-28 15:31:23.494646+00	2026-05-28 15:31:23.494646+00
b1ede3b9-6dbc-4fb4-9892-106abd9353a3	8e45827b-5be0-4d80-bf30-15a27352e01a	cbdaef09-f8f4-4199-a077-116b753218bf	364c27f9fa1c944a6e0561c194584e3a4fd1890525b93d746dd0709e502acd24	\N	\N	t	2026-05-29 15:34:40.788638+00	2026-05-28 15:34:40.789773+00	2026-05-28 15:34:40.789773+00
c16332cd-6f6c-4e4c-bff0-4abf4d74edc5	e4039479-cd41-4e84-829b-f6ca55a3a1d5	9d47cec6-5f1a-48c2-8aef-2ae53c267ca7	b4e1677e566ea191f8e23054605d228d38f503084795e94719fed66a09a7ce57	\N	\N	t	2026-05-30 10:56:17.181718+00	2026-05-29 10:56:17.182816+00	2026-05-29 10:56:17.182816+00
3ea44b7e-2b00-4d6f-9124-578d0d68f02f	d302c193-3c42-4837-9897-731e43cf4c9e	005d0831-36c7-4d44-bb52-6d9a13bacb4d	408e265801d020470fc03deab58b808df31adc6fa6a9f21762b7a2dad5a0e9df	\N	\N	t	2026-05-30 12:47:24.991421+00	2026-05-29 12:47:24.992492+00	2026-05-29 12:47:24.992492+00
700265cb-d995-454f-997e-9518703acdc3	00abb788-21e2-4703-807c-d6e93e04a2c9	5359c3a9-2913-48b8-888c-00fbfd84682f	0df0bce649f9dce1d647cd2182673ccde60d902e021363e9292fbdd79aaa9fe1	\N	\N	t	2026-05-30 12:47:43.851614+00	2026-05-29 12:47:43.852621+00	2026-05-29 12:47:43.852621+00
919f64b0-e1e9-450e-a119-e50a77c81158	00abb788-21e2-4703-807c-d6e93e04a2c9	5359c3a9-2913-48b8-888c-00fbfd84682f	17ec678ef28df12eb07563c502949132f1d7f85ca69fca7312b919370c5d603a	\N	\N	t	2026-05-30 12:48:59.339476+00	2026-05-29 12:48:59.340613+00	2026-05-29 12:48:59.340613+00
09bb530a-aa34-4675-9d21-1c6c41ca7fd9	e4039479-cd41-4e84-829b-f6ca55a3a1d5	9d47cec6-5f1a-48c2-8aef-2ae53c267ca7	7cba97e6fe068c6a887533d181c453fa0fe46f08e85498d4dc6f62e41119ae75	\N	\N	t	2026-05-30 13:35:59.079183+00	2026-05-29 13:35:59.079968+00	2026-05-29 13:35:59.079968+00
74f0db43-99c3-43c4-907f-60b55645209b	c210cc84-1c68-4506-9242-a4314bdb1d14	841689d4-2d6a-4391-b453-930e6fbb35a5	31d38f4a2a64ee19a79ac61161625785183164c788066054e044e5ac592895c5	\N	\N	t	2026-05-31 01:37:04.408296+00	2026-05-30 01:37:04.409323+00	2026-05-30 01:37:04.409323+00
ef4e0a5e-8bcd-46aa-b9c7-2e3b473e2e16	c210cc84-1c68-4506-9242-a4314bdb1d14	841689d4-2d6a-4391-b453-930e6fbb35a5	085f9e22f1baf0c9927200c39cadf10b414d48c8655125c4e970c24b0f29c81c	\N	\N	t	2026-05-31 13:06:33.452612+00	2026-05-30 13:06:33.454122+00	2026-05-30 13:06:33.454122+00
04bbbb75-8158-4dd4-8037-130f2216dfd7	d302c193-3c42-4837-9897-731e43cf4c9e	005d0831-36c7-4d44-bb52-6d9a13bacb4d	741c98c2bd2a9a57dff1bb74d0aea8fd0597a5ad71e469c67dbfccbcd58a1eae	\N	\N	t	2026-05-31 13:46:20.417457+00	2026-05-30 13:46:20.425408+00	2026-05-30 13:46:20.425408+00
c5ab0486-9124-4e31-b81a-dfeada31df69	8e45827b-5be0-4d80-bf30-15a27352e01a	cbdaef09-f8f4-4199-a077-116b753218bf	46032c701f375ed14db6118e09009da10bcf011ca6de0532d0d67750c11c0438	\N	\N	t	2026-06-01 13:27:52.415286+00	2026-05-31 13:27:52.42722+00	2026-05-31 13:27:52.42722+00
8c7488a6-49f0-4262-b4f7-f2bc0f98243e	e4039479-cd41-4e84-829b-f6ca55a3a1d5	9d47cec6-5f1a-48c2-8aef-2ae53c267ca7	c783f08587bbd3c9a2fe9e6c52058cabd23ec890b10d8689518873b94e3981ef	\N	\N	t	2026-06-03 10:14:19.760783+00	2026-06-02 10:14:19.765703+00	2026-06-02 10:14:19.765703+00
851a8259-1518-4ba5-a734-65d5b6f18d11	3d7c2c89-c55b-4d20-92a4-59fb45f58829	07ab628b-6aa2-47e9-9893-fbdd583a7cba	a4238f390b369c7ea36068bce10161899d8aea309d36a87f99c77505e5ec2c93	\N	\N	t	2026-06-04 08:16:30.715505+00	2026-06-03 08:16:30.72009+00	2026-06-03 08:16:30.72009+00
16bde8f2-e38e-470b-bc9a-fa8f51d13cd0	3d7c2c89-c55b-4d20-92a4-59fb45f58829	07ab628b-6aa2-47e9-9893-fbdd583a7cba	cd3aaf1de9e49afb2bcc034a2968a065072c8ba30c2127b8f9f446a45228e4bc	\N	\N	t	2026-06-05 06:42:47.990387+00	2026-06-04 06:42:47.991419+00	2026-06-04 06:42:47.991419+00
ac7a9495-e78e-4905-9dc0-023026e35efa	3d7c2c89-c55b-4d20-92a4-59fb45f58829	07ab628b-6aa2-47e9-9893-fbdd583a7cba	ea1deb587ff6715166d6328e4da10e7c239efcb3cc1e329abde646a9b2a62cfc	\N	\N	t	2026-06-05 11:23:59.932244+00	2026-06-04 11:23:59.932461+00	2026-06-04 11:23:59.932461+00
c89b71cf-9a66-4703-b40e-bcef45f964c0	3d7c2c89-c55b-4d20-92a4-59fb45f58829	07ab628b-6aa2-47e9-9893-fbdd583a7cba	005398501095e6f8e68e5df63bea8e6ed421e25d40404a295ff4322c45c4afe9	\N	\N	t	2026-06-09 11:47:03.070776+00	2026-06-08 11:47:03.063824+00	2026-06-08 11:47:03.063824+00
19f4a2b5-4be9-4123-bd7e-d2710a6236cd	8e45827b-5be0-4d80-bf30-15a27352e01a	cbdaef09-f8f4-4199-a077-116b753218bf	9661729bee27ac752ac44ef10e2287713c908511659a992a56390eb8fd417f4c	\N	\N	t	2026-06-10 05:05:35.882829+00	2026-06-09 05:05:35.876712+00	2026-06-09 05:05:35.876712+00
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.users (id, org_id, email, name, role, password_hash, is_active, last_login_at, preferences, created_at, updated_at, auth_provider, google_sub) FROM stdin;
00000000-0000-0000-0000-000000000002	00000000-0000-0000-0000-000000000001	admin@agro-exports.example	Admin	admin	\N	t	\N	{}	2026-05-22 11:40:48.194571+00	2026-05-26 15:28:00.47132+00	email	\N
2beeb91b-32b2-4541-9dac-0439818f7d1d	3401cbbd-dc58-4278-9e77-48314c1c1f9b	testowner_4c7129@example.com	Owner 4c7129	owner	$2a$06$MtbHmtWTRfcPw1.Fpp6vzegnP22N7XAz3RQQFjbvnN0LvXREJPKV6	t	2026-05-27 14:17:34.073554+00	{}	2026-05-27 14:17:30.560898+00	2026-05-27 14:17:34.073554+00	email	\N
00abb788-21e2-4703-807c-d6e93e04a2c9	5359c3a9-2913-48b8-888c-00fbfd84682f	ompatra112006@gmail.com	Om Patra	owner	\N	t	2026-05-29 12:48:59.327341+00	{}	2026-05-29 12:47:43.831104+00	2026-05-29 12:48:59.327341+00	google	110190837336866237121
c210cc84-1c68-4506-9242-a4314bdb1d14	841689d4-2d6a-4391-b453-930e6fbb35a5	dhiraj.patra@gmail.com	Dhiraj Patra	owner	\N	t	2026-05-30 13:06:33.446636+00	{}	2026-05-30 01:37:04.392724+00	2026-05-30 13:06:33.446636+00	google	117305352517568057882
d302c193-3c42-4837-9897-731e43cf4c9e	005d0831-36c7-4d44-bb52-6d9a13bacb4d	patraom49@gmail.com	Om Patra	owner	\N	t	2026-05-30 13:46:20.393321+00	{}	2026-05-29 12:47:24.963132+00	2026-05-30 13:46:20.393321+00	google	108775062476372291950
e4039479-cd41-4e84-829b-f6ca55a3a1d5	9d47cec6-5f1a-48c2-8aef-2ae53c267ca7	patratanushree1982@gmail.com	Tanushree Patra	owner	\N	t	2026-06-02 10:14:19.754361+00	{}	2026-05-28 15:31:23.453005+00	2026-06-02 10:14:19.754361+00	google	100889286373883314052
3d7c2c89-c55b-4d20-92a4-59fb45f58829	07ab628b-6aa2-47e9-9893-fbdd583a7cba	demo-admin@exportagent.online	Demo User	admin	$2a$06$HQVz2xxVcTgMiOWF1Yy3zebA4A28vs8Yyi3wRO7E9/IUIsllWVah6	t	2026-06-08 11:47:03.053317+00	{}	2026-05-25 08:16:23.739164+00	2026-06-08 11:47:03.053317+00	email	\N
8e45827b-5be0-4d80-bf30-15a27352e01a	cbdaef09-f8f4-4199-a077-116b753218bf	tanusreepatra@gmail.com	Tanushree Patra	owner	\N	t	2026-06-09 05:05:35.86427+00	{}	2026-05-28 15:34:40.78015+00	2026-06-09 05:05:35.86427+00	google	110365319178455335081
\.


--
-- Data for Name: workflow_steps; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.workflow_steps (id, workflow_id, step_name, agent_name, status, input, output, error, ai_confidence, tokens_used, latency_ms, retry_count, started_at, completed_at, created_at) FROM stdin;
ac308a26-3687-4e26-9809-e55c681ad1ca	ef000000-0000-0000-0000-000000000001	po_extraction	po_extraction_agent	completed	\N	{"items": 1, "currency": "USD", "destination": "Dubai"}	\N	87.50	\N	21400	0	2026-05-21 04:41:50.068651+00	2026-05-21 04:42:11.068651+00	2026-05-23 04:41:50.068651+00
9b42b5bc-9990-4a3f-aa07-ba13ccb262db	ef000000-0000-0000-0000-000000000001	clarification_check	\N	completed	\N	{"blocked": false, "question_count": 0}	\N	\N	\N	120	0	2026-05-21 04:42:11.068651+00	2026-05-21 04:42:11.068651+00	2026-05-23 04:41:50.068651+00
2ed66600-d93b-4862-8125-cb3ad4d4bb71	ef000000-0000-0000-0000-000000000001	hs_validation	hs_validation_agent	completed	\N	{"flags": [], "overall_clearance": true}	\N	92.00	\N	42300	0	2026-05-21 04:42:12.068651+00	2026-05-21 04:42:54.068651+00	2026-05-23 04:41:50.068651+00
1f80a28a-60d6-40df-82e8-16ec43d59cfa	ef000000-0000-0000-0000-000000000001	doc_generation	doc_generation_agent	completed	\N	{"docs": ["commercial_invoice", "packing_list"]}	\N	95.00	\N	86700	0	2026-05-21 04:42:55.068651+00	2026-05-21 04:44:22.068651+00	2026-05-23 04:41:50.068651+00
9100af1f-ee19-4e53-92c7-a21da7c0d1fb	ef000000-0000-0000-0000-000000000001	hitl_evaluation	\N	completed	\N	{"decision": "auto_approve", "requires_human": false}	\N	87.50	\N	50	0	2026-05-21 04:44:23.068651+00	2026-05-21 04:44:23.068651+00	2026-05-23 04:41:50.068651+00
72d65d6f-2a25-497c-94d4-1c9878d5dc4e	ef000000-0000-0000-0000-000000000001	dispatch	\N	completed	\N	{"sent": true, "channel": "whatsapp"}	\N	\N	\N	1200	0	2026-05-21 04:44:24.068651+00	2026-05-21 04:44:25.068651+00	2026-05-23 04:41:50.068651+00
ab935d10-a007-4a0e-b436-8eb608606a10	ef000000-0000-0000-0000-000000000002	po_extraction	po_extraction_agent	completed	\N	{"items": 1, "currency": "USD"}	\N	72.00	\N	42100	0	2026-05-23 01:41:50.068651+00	2026-05-23 01:42:32.068651+00	2026-05-23 04:41:50.068651+00
3f5b2b4b-cd65-474c-8d99-c134cfd0bb7d	ef000000-0000-0000-0000-000000000002	clarification_check	\N	completed	\N	{"blocked": false, "question_count": 1}	\N	\N	\N	90	0	2026-05-23 01:42:32.068651+00	2026-05-23 01:42:33.068651+00	2026-05-23 04:41:50.068651+00
b42f457f-0604-491d-8f54-d137d6ed9221	ef000000-0000-0000-0000-000000000002	hs_validation	hs_validation_agent	completed	\N	{"overall_clearance": true}	\N	78.00	\N	39800	0	2026-05-23 01:42:33.068651+00	2026-05-23 01:43:13.068651+00	2026-05-23 04:41:50.068651+00
382da4d6-d609-4c85-a3ff-8576c5df63a0	ef000000-0000-0000-0000-000000000002	doc_generation	doc_generation_agent	completed	\N	{"docs": ["commercial_invoice", "packing_list"]}	\N	72.00	\N	91200	0	2026-05-23 01:43:14.068651+00	2026-05-23 01:44:45.068651+00	2026-05-23 04:41:50.068651+00
9eef23cc-b792-4445-af60-5b3a1b741a43	ef000000-0000-0000-0000-000000000002	hitl_evaluation	\N	running	\N	\N	\N	72.00	\N	\N	0	2026-05-23 01:44:46.068651+00	\N	2026-05-23 04:41:50.068651+00
ef5fa54e-ff40-484c-8d35-9e428e702e6a	ef000000-0000-0000-0000-000000000004	po_extraction	po_extraction_agent	completed	\N	{"items": 1, "currency": "USD"}	\N	89.00	\N	20100	0	2026-05-18 04:41:50.068651+00	2026-05-18 04:42:10.068651+00	2026-05-23 04:41:50.068651+00
2458e954-bbd5-4b79-9a2b-2e0cc7e111b4	ef000000-0000-0000-0000-000000000004	clarification_check	\N	completed	\N	{"blocked": false, "question_count": 0}	\N	\N	\N	85	0	2026-05-18 04:42:10.068651+00	2026-05-18 04:42:11.068651+00	2026-05-23 04:41:50.068651+00
6d5fe480-7194-485a-9b84-19fd95990193	ef000000-0000-0000-0000-000000000004	hs_validation	hs_validation_agent	completed	\N	{"overall_clearance": true}	\N	91.00	\N	40200	0	2026-05-18 04:42:11.068651+00	2026-05-18 04:42:51.068651+00	2026-05-23 04:41:50.068651+00
a6a15e51-c080-4eb0-b914-78c977001f37	ef000000-0000-0000-0000-000000000004	doc_generation	doc_generation_agent	completed	\N	{"docs": ["commercial_invoice", "packing_list"]}	\N	93.00	\N	82300	0	2026-05-18 04:42:52.068651+00	2026-05-18 04:44:14.068651+00	2026-05-23 04:41:50.068651+00
baa697ea-4bd5-419d-84db-776baa14b311	ef000000-0000-0000-0000-000000000004	hitl_evaluation	\N	completed	\N	{"decision": "auto_approve", "requires_human": false}	\N	89.00	\N	45	0	2026-05-18 04:44:15.068651+00	2026-05-18 04:44:15.068651+00	2026-05-23 04:41:50.068651+00
c4876bd2-8d68-43bf-83e5-acce2510ea2c	ef000000-0000-0000-0000-000000000004	dispatch	\N	completed	\N	{"sent": true, "channel": "whatsapp"}	\N	\N	\N	980	0	2026-05-18 04:44:16.068651+00	2026-05-18 04:44:17.068651+00	2026-05-23 04:41:50.068651+00
\.


--
-- Data for Name: workflows; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.workflows (id, org_id, order_id, name, status, current_step, temporal_workflow_id, temporal_run_id, state_snapshot, context, started_at, completed_at, timeout_at, created_at) FROM stdin;
ef000000-0000-0000-0000-000000000001	00000000-0000-0000-0000-000000000001	a1000000-0000-0000-0000-000000000001	PO to Dispatch — WA-A1000001	completed	dispatch	\N	\N	{"buyer": "Al Noor Foodstuff Trading LLC", "source": "whatsapp", "confidence": 87.5}	{}	2026-05-21 04:41:50.068651+00	2026-05-21 05:41:50.068651+00	\N	2026-05-23 04:41:50.068651+00
ef000000-0000-0000-0000-000000000004	00000000-0000-0000-0000-000000000001	a1000000-0000-0000-0000-000000000004	PO to Dispatch — WA-A1000004	completed	dispatch	\N	\N	{"buyer": "Al Noor Foodstuff Trading LLC", "source": "whatsapp", "confidence": 89.0}	{}	2026-05-18 04:41:50.068651+00	2026-05-18 06:41:50.068651+00	\N	2026-05-23 04:41:50.068651+00
b249a40d-537c-4b26-bb7d-d91b2d63c1da	00000000-0000-0000-0000-000000000001	\N	po_to_dispatch	running	hitl_decision	\N	\N	{}	{"source": "portal", "overall_confidence": 60.0}	2026-05-23 10:52:55.688782+00	\N	\N	2026-05-23 10:52:55.688782+00
5cb9440f-5a3d-4c7e-8d3c-9c185aceed4e	00000000-0000-0000-0000-000000000001	\N	po_to_dispatch	completed	hitl_decision	\N	\N	{}	{"source": "portal", "overall_confidence": 45.0}	2026-05-23 14:49:04.347491+00	\N	\N	2026-05-23 14:49:04.347491+00
ffbe6cc8-a990-4036-9078-3db7ee26072b	00000000-0000-0000-0000-000000000001	\N	po_to_dispatch	completed	hitl_decision	\N	\N	{}	{"source": "whatsapp", "overall_confidence": 45.0}	2026-05-23 11:33:19.350588+00	\N	\N	2026-05-23 11:33:19.350588+00
a90e7e81-2713-4731-aad7-edfe4c1ac77a	00000000-0000-0000-0000-000000000001	\N	po_to_dispatch	completed	hitl_decision	\N	\N	{}	{"source": "portal", "overall_confidence": 45.0}	2026-05-23 06:23:32.627895+00	\N	\N	2026-05-23 06:23:32.627895+00
ef000000-0000-0000-0000-000000000002	00000000-0000-0000-0000-000000000001	a1000000-0000-0000-0000-000000000002	PO to Dispatch — WA-A1000002	completed	hitl_evaluation	\N	\N	{"buyer": "Gulf Fresh General Trading", "source": "whatsapp", "confidence": 72.0}	{}	2026-05-23 01:41:50.068651+00	\N	\N	2026-05-23 04:41:50.068651+00
dd300701-c9ad-478e-bc6c-33623d27b9bb	00000000-0000-0000-0000-000000000001	\N	po_to_dispatch	completed	hitl_decision	\N	\N	{}	{"source": "portal", "overall_confidence": 45.0}	2026-05-23 15:04:22.034358+00	\N	\N	2026-05-23 15:04:22.034358+00
6ed40049-12da-4197-be3f-e1636270446b	00000000-0000-0000-0000-000000000001	\N	po_to_dispatch	completed	hitl_decision	\N	\N	{}	{"source": "whatsapp", "overall_confidence": 45.0}	2026-05-23 10:44:15.592358+00	\N	\N	2026-05-23 10:44:15.592358+00
89f714b4-1382-4117-be0a-2357ada57c27	00000000-0000-0000-0000-000000000001	\N	po_to_dispatch	completed	hitl_decision	\N	\N	{}	{"source": "portal", "overall_confidence": 45.0}	2026-05-23 10:26:02.789206+00	\N	\N	2026-05-23 10:26:02.789206+00
3c7d209a-a09b-4d0b-90d2-edd4bcecbc20	00000000-0000-0000-0000-000000000001	\N	po_to_dispatch	completed	hitl_decision	\N	\N	{}	{"source": "portal", "overall_confidence": 55.0}	2026-05-23 15:32:26.431209+00	\N	\N	2026-05-23 15:32:26.431209+00
6161ae6e-d3b4-433d-941f-4cc0c5c56589	00000000-0000-0000-0000-000000000001	\N	po_to_dispatch	running	hitl_decision	\N	\N	{}	{"source": "whatsapp", "overall_confidence": 60.0}	2026-05-23 15:58:26.615298+00	\N	\N	2026-05-23 15:58:26.615298+00
976e67cd-9269-4693-9a58-b7d1e0c2a2f7	00000000-0000-0000-0000-000000000001	\N	po_to_dispatch	completed	hitl_decision	\N	\N	{}	{"source": "portal", "overall_confidence": 45.0}	2026-05-23 15:58:06.730198+00	\N	\N	2026-05-23 15:58:06.730198+00
271403d6-3473-4e10-8679-5f61d39fb47d	00000000-0000-0000-0000-000000000001	\N	po_to_dispatch	completed	hitl_decision	\N	\N	{}	{"source": "whatsapp", "overall_confidence": 45.0}	2026-05-24 08:41:47.893725+00	\N	\N	2026-05-24 08:41:47.893725+00
2a088130-3a97-49d7-aa89-46f10ad5712d	00000000-0000-0000-0000-000000000001	\N	po_to_dispatch	completed	hitl_decision	\N	\N	{}	{"source": "portal", "overall_confidence": 45.0}	2026-05-26 14:03:31.338858+00	\N	\N	2026-05-26 14:03:31.338858+00
e6d77cda-4d26-494c-af9c-54cd6a400bfa	00000000-0000-0000-0000-000000000001	\N	po_to_dispatch	completed	hitl_decision	\N	\N	{}	{"source": "portal", "overall_confidence": 45.0}	2026-05-26 14:02:50.323936+00	\N	\N	2026-05-26 14:02:50.323936+00
4a362369-50d6-475e-8a2c-4604360c9518	00000000-0000-0000-0000-000000000001	\N	po_to_dispatch	completed	hitl_decision	\N	\N	{}	{"source": "file", "overall_confidence": 45.0}	2026-05-26 13:56:07.758067+00	\N	\N	2026-05-26 13:56:07.758067+00
861458b2-05a9-4e22-82ce-8e14614c655b	00000000-0000-0000-0000-000000000001	\N	po_to_dispatch	completed	hitl_decision	\N	\N	{}	{"source": "portal", "overall_confidence": 45.0}	2026-05-26 14:38:37.848371+00	\N	\N	2026-05-26 14:38:37.848371+00
f46c42a3-0dc2-47aa-95d9-babbaf9ec983	00000000-0000-0000-0000-000000000001	\N	po_to_dispatch	awaiting_human	hitl_decision	\N	\N	{}	{"source": "file", "overall_confidence": 45.0}	2026-05-27 03:21:07.703876+00	\N	\N	2026-05-27 03:21:07.703876+00
e9ef93f8-b72f-4bd9-8722-de8458107f96	00000000-0000-0000-0000-000000000001	\N	po_to_dispatch	awaiting_human	hitl_decision	\N	\N	{}	{"source": "file", "overall_confidence": 40.0}	2026-05-27 04:48:23.452872+00	\N	\N	2026-05-27 04:48:23.452872+00
240c464a-825a-4b00-a426-ee9e1f9d8329	00000000-0000-0000-0000-000000000001	\N	po_to_dispatch	awaiting_human	hitl_decision	\N	\N	{}	{"source": "file", "overall_confidence": 40.0}	2026-05-27 04:49:32.766035+00	\N	\N	2026-05-27 04:49:32.766035+00
21fefa83-b1bf-43a3-b0d8-03dec8de4bed	00000000-0000-0000-0000-000000000001	\N	po_to_dispatch	awaiting_human	hitl_decision	\N	\N	{}	{"source": "file", "overall_confidence": 55.0}	2026-05-27 06:29:11.74562+00	\N	\N	2026-05-27 06:29:11.74562+00
3b1397ca-8f33-458d-bbd9-eb7dd0498fcf	00000000-0000-0000-0000-000000000001	\N	po_to_dispatch	running	hitl_decision	\N	\N	{}	{"source": "file", "overall_confidence": 60.0}	2026-05-29 06:07:40.914948+00	\N	\N	2026-05-29 06:07:40.914948+00
6207f055-1ad7-4ddf-9b34-6cf4b2610286	5359c3a9-2913-48b8-888c-00fbfd84682f	\N	po_to_dispatch	awaiting_human	hitl_decision	\N	\N	{}	{"source": "portal", "overall_confidence": 45.0}	2026-05-29 12:51:40.821717+00	\N	\N	2026-05-29 12:51:40.821717+00
110dbe43-e6cb-4506-8212-659f5cf5b9f6	841689d4-2d6a-4391-b453-930e6fbb35a5	\N	po_to_dispatch	running	hitl_decision	\N	\N	{}	{"source": "portal", "overall_confidence": 60.0}	2026-05-30 01:37:58.782426+00	\N	\N	2026-05-30 01:37:58.782426+00
32268ef0-d5ed-49b5-8877-2f5c9f5df5bc	005d0831-36c7-4d44-bb52-6d9a13bacb4d	\N	po_to_dispatch	awaiting_human	hitl_decision	\N	\N	{}	{"source": "portal", "overall_confidence": 45.0}	2026-05-30 13:48:30.49594+00	\N	\N	2026-05-30 13:48:30.49594+00
866c5538-1881-40ad-9706-35eddd61c7c6	07ab628b-6aa2-47e9-9893-fbdd583a7cba	\N	po_to_dispatch	running	hitl_decision	\N	\N	{}	{"source": "portal", "overall_confidence": 60.0}	2026-06-04 11:24:36.018349+00	\N	\N	2026-06-04 11:24:36.018349+00
\.


--
-- Name: audit_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: neondb_owner
--

SELECT pg_catalog.setval('public.audit_log_id_seq', 18, true);


--
-- Name: agent_memory agent_memory_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.agent_memory
    ADD CONSTRAINT agent_memory_pkey PRIMARY KEY (id);


--
-- Name: approval_requests approval_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.approval_requests
    ADD CONSTRAINT approval_requests_pkey PRIMARY KEY (id);


--
-- Name: audit_log audit_log_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT audit_log_pkey PRIMARY KEY (id);


--
-- Name: contacts contacts_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.contacts
    ADD CONSTRAINT contacts_pkey PRIMARY KEY (id);


--
-- Name: country_trade_rules country_trade_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.country_trade_rules
    ADD CONSTRAINT country_trade_rules_pkey PRIMARY KEY (id);


--
-- Name: documents documents_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_pkey PRIMARY KEY (id);


--
-- Name: hitl_corrections hitl_corrections_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.hitl_corrections
    ADD CONSTRAINT hitl_corrections_pkey PRIMARY KEY (id);


--
-- Name: hs_codes hs_codes_code_key; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.hs_codes
    ADD CONSTRAINT hs_codes_code_key UNIQUE (code);


--
-- Name: hs_codes hs_codes_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.hs_codes
    ADD CONSTRAINT hs_codes_pkey PRIMARY KEY (id);


--
-- Name: logistics_rate_cards logistics_rate_cards_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.logistics_rate_cards
    ADD CONSTRAINT logistics_rate_cards_pkey PRIMARY KEY (id);


--
-- Name: logistics_vendors logistics_vendors_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.logistics_vendors
    ADD CONSTRAINT logistics_vendors_pkey PRIMARY KEY (id);


--
-- Name: mcp_api_keys mcp_api_keys_key_hash_key; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.mcp_api_keys
    ADD CONSTRAINT mcp_api_keys_key_hash_key UNIQUE (key_hash);


--
-- Name: mcp_api_keys mcp_api_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.mcp_api_keys
    ADD CONSTRAINT mcp_api_keys_pkey PRIMARY KEY (id);


--
-- Name: mcp_billing mcp_billing_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.mcp_billing
    ADD CONSTRAINT mcp_billing_pkey PRIMARY KEY (id);


--
-- Name: mcp_usage_log mcp_usage_log_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.mcp_usage_log
    ADD CONSTRAINT mcp_usage_log_pkey PRIMARY KEY (id);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);


--
-- Name: order_items order_items_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_pkey PRIMARY KEY (id);


--
-- Name: orders orders_org_id_order_number_key; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_org_id_order_number_key UNIQUE (org_id, order_number);


--
-- Name: orders orders_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (id);


--
-- Name: organizations organizations_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT organizations_pkey PRIMARY KEY (id);


--
-- Name: organizations organizations_slug_key; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT organizations_slug_key UNIQUE (slug);


--
-- Name: po_templates po_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.po_templates
    ADD CONSTRAINT po_templates_pkey PRIMARY KEY (id);


--
-- Name: products products_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_pkey PRIMARY KEY (id);


--
-- Name: prompt_registry prompt_registry_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.prompt_registry
    ADD CONSTRAINT prompt_registry_pkey PRIMARY KEY (id);


--
-- Name: shipment_events shipment_events_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.shipment_events
    ADD CONSTRAINT shipment_events_pkey PRIMARY KEY (id);


--
-- Name: shipments shipments_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.shipments
    ADD CONSTRAINT shipments_pkey PRIMARY KEY (id);


--
-- Name: mcp_api_keys uq_mcp_api_keys_org_env; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.mcp_api_keys
    ADD CONSTRAINT uq_mcp_api_keys_org_env UNIQUE (org_id, environment);


--
-- Name: mcp_billing uq_mcp_billing_org_period; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.mcp_billing
    ADD CONSTRAINT uq_mcp_billing_org_period UNIQUE (org_id, period_start);


--
-- Name: po_templates uq_po_templates_org_buyer; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.po_templates
    ADD CONSTRAINT uq_po_templates_org_buyer UNIQUE (org_id, buyer_key);


--
-- Name: user_sessions user_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.user_sessions
    ADD CONSTRAINT user_sessions_pkey PRIMARY KEY (id);


--
-- Name: user_sessions user_sessions_token_key; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.user_sessions
    ADD CONSTRAINT user_sessions_token_key UNIQUE (token);


--
-- Name: users users_google_sub_key; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_google_sub_key UNIQUE (google_sub);


--
-- Name: users users_org_id_email_key; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_org_id_email_key UNIQUE (org_id, email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: workflow_steps workflow_steps_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.workflow_steps
    ADD CONSTRAINT workflow_steps_pkey PRIMARY KEY (id);


--
-- Name: workflows workflows_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.workflows
    ADD CONSTRAINT workflows_pkey PRIMARY KEY (id);


--
-- Name: idx_approvals_assigned; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_approvals_assigned ON public.approval_requests USING btree (assigned_to, status);


--
-- Name: idx_approvals_org_status; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_approvals_org_status ON public.approval_requests USING btree (org_id, status);


--
-- Name: idx_audit_org_entity; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_audit_org_entity ON public.audit_log USING btree (org_id, entity_type, entity_id);


--
-- Name: idx_contacts_org; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_contacts_org ON public.contacts USING btree (org_id);


--
-- Name: idx_country_rules_route; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_country_rules_route ON public.country_trade_rules USING btree (from_country, to_country);


--
-- Name: idx_documents_org_order; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_documents_org_order ON public.documents USING btree (org_id, order_id);


--
-- Name: idx_documents_type_status; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_documents_type_status ON public.documents USING btree (doc_type, status);


--
-- Name: idx_hitl_corrections_org_buyer; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_hitl_corrections_org_buyer ON public.hitl_corrections USING btree (org_id, buyer_key);


--
-- Name: idx_hitl_corrections_org_field; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_hitl_corrections_org_field ON public.hitl_corrections USING btree (org_id, field_name);


--
-- Name: idx_hitl_corrections_workflow; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_hitl_corrections_workflow ON public.hitl_corrections USING btree (workflow_id);


--
-- Name: idx_hs_embedding; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_hs_embedding ON public.hs_codes USING ivfflat (embedding public.vector_cosine_ops) WITH (lists='100');


--
-- Name: idx_logistics_rate_cards_vendor; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_logistics_rate_cards_vendor ON public.logistics_rate_cards USING btree (vendor_id);


--
-- Name: idx_logistics_vendors_org; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_logistics_vendors_org ON public.logistics_vendors USING btree (org_id);


--
-- Name: idx_mcp_usage_org_month; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_mcp_usage_org_month ON public.mcp_usage_log USING btree (org_id, date_trunc('month'::text, (created_at AT TIME ZONE 'UTC'::text)));


--
-- Name: idx_memory_embedding; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_memory_embedding ON public.agent_memory USING ivfflat (embedding public.vector_cosine_ops) WITH (lists='100');


--
-- Name: idx_memory_org_agent; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_memory_org_agent ON public.agent_memory USING btree (org_id, agent_name, memory_type);


--
-- Name: idx_memory_scope; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_memory_scope ON public.agent_memory USING btree (scope_type, scope_id);


--
-- Name: idx_messages_contact; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_messages_contact ON public.messages USING btree (contact_id, created_at DESC);


--
-- Name: idx_messages_org_order; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_messages_org_order ON public.messages USING btree (org_id, order_id);


--
-- Name: idx_po_templates_org_buyer; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_po_templates_org_buyer ON public.po_templates USING btree (org_id, buyer_key);


--
-- Name: idx_po_templates_org_use; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_po_templates_org_use ON public.po_templates USING btree (org_id, use_count DESC);


--
-- Name: idx_products_org_sku; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE UNIQUE INDEX idx_products_org_sku ON public.products USING btree (org_id, sku);


--
-- Name: idx_prompt_active; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_prompt_active ON public.prompt_registry USING btree (agent_name, prompt_key, is_active);


--
-- Name: idx_prompt_agent_key_version; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE UNIQUE INDEX idx_prompt_agent_key_version ON public.prompt_registry USING btree (agent_name, prompt_key, version);


--
-- Name: idx_sessions_org; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_sessions_org ON public.user_sessions USING btree (org_id);


--
-- Name: idx_sessions_user_token; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_sessions_user_token ON public.user_sessions USING btree (user_id, token);


--
-- Name: idx_users_org; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_users_org ON public.users USING btree (org_id);


--
-- Name: idx_workflow_steps_workflow; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_workflow_steps_workflow ON public.workflow_steps USING btree (workflow_id);


--
-- Name: agent_memory trg_agent_memory_updated_at; Type: TRIGGER; Schema: public; Owner: neondb_owner
--

CREATE TRIGGER trg_agent_memory_updated_at BEFORE UPDATE ON public.agent_memory FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: contacts trg_contacts_updated_at; Type: TRIGGER; Schema: public; Owner: neondb_owner
--

CREATE TRIGGER trg_contacts_updated_at BEFORE UPDATE ON public.contacts FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: documents trg_documents_updated_at; Type: TRIGGER; Schema: public; Owner: neondb_owner
--

CREATE TRIGGER trg_documents_updated_at BEFORE UPDATE ON public.documents FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: logistics_rate_cards trg_logistics_rate_cards_updated_at; Type: TRIGGER; Schema: public; Owner: neondb_owner
--

CREATE TRIGGER trg_logistics_rate_cards_updated_at BEFORE UPDATE ON public.logistics_rate_cards FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: logistics_vendors trg_logistics_vendors_updated_at; Type: TRIGGER; Schema: public; Owner: neondb_owner
--

CREATE TRIGGER trg_logistics_vendors_updated_at BEFORE UPDATE ON public.logistics_vendors FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: orders trg_orders_updated_at; Type: TRIGGER; Schema: public; Owner: neondb_owner
--

CREATE TRIGGER trg_orders_updated_at BEFORE UPDATE ON public.orders FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: organizations trg_organizations_updated_at; Type: TRIGGER; Schema: public; Owner: neondb_owner
--

CREATE TRIGGER trg_organizations_updated_at BEFORE UPDATE ON public.organizations FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: po_templates trg_po_templates_updated_at; Type: TRIGGER; Schema: public; Owner: neondb_owner
--

CREATE TRIGGER trg_po_templates_updated_at BEFORE UPDATE ON public.po_templates FOR EACH ROW EXECUTE FUNCTION public.update_po_templates_updated_at();


--
-- Name: products trg_products_updated_at; Type: TRIGGER; Schema: public; Owner: neondb_owner
--

CREATE TRIGGER trg_products_updated_at BEFORE UPDATE ON public.products FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: shipments trg_shipments_updated_at; Type: TRIGGER; Schema: public; Owner: neondb_owner
--

CREATE TRIGGER trg_shipments_updated_at BEFORE UPDATE ON public.shipments FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: users trg_users_updated_at; Type: TRIGGER; Schema: public; Owner: neondb_owner
--

CREATE TRIGGER trg_users_updated_at BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: agent_memory agent_memory_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.agent_memory
    ADD CONSTRAINT agent_memory_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: approval_requests approval_requests_assigned_to_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.approval_requests
    ADD CONSTRAINT approval_requests_assigned_to_fkey FOREIGN KEY (assigned_to) REFERENCES public.users(id);


--
-- Name: approval_requests approval_requests_document_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.approval_requests
    ADD CONSTRAINT approval_requests_document_id_fkey FOREIGN KEY (document_id) REFERENCES public.documents(id);


--
-- Name: approval_requests approval_requests_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.approval_requests
    ADD CONSTRAINT approval_requests_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id);


--
-- Name: approval_requests approval_requests_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.approval_requests
    ADD CONSTRAINT approval_requests_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: approval_requests approval_requests_reviewed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.approval_requests
    ADD CONSTRAINT approval_requests_reviewed_by_fkey FOREIGN KEY (reviewed_by) REFERENCES public.users(id);


--
-- Name: approval_requests approval_requests_workflow_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.approval_requests
    ADD CONSTRAINT approval_requests_workflow_id_fkey FOREIGN KEY (workflow_id) REFERENCES public.workflows(id);


--
-- Name: approval_requests approval_requests_workflow_step_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.approval_requests
    ADD CONSTRAINT approval_requests_workflow_step_id_fkey FOREIGN KEY (workflow_step_id) REFERENCES public.workflow_steps(id);


--
-- Name: contacts contacts_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.contacts
    ADD CONSTRAINT contacts_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: documents documents_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id);


--
-- Name: documents documents_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: documents documents_parent_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_parent_version_id_fkey FOREIGN KEY (parent_version_id) REFERENCES public.documents(id);


--
-- Name: documents documents_reviewed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_reviewed_by_fkey FOREIGN KEY (reviewed_by) REFERENCES public.users(id);


--
-- Name: hitl_corrections hitl_corrections_corrected_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.hitl_corrections
    ADD CONSTRAINT hitl_corrections_corrected_by_fkey FOREIGN KEY (corrected_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: hitl_corrections hitl_corrections_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.hitl_corrections
    ADD CONSTRAINT hitl_corrections_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: logistics_rate_cards logistics_rate_cards_vendor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.logistics_rate_cards
    ADD CONSTRAINT logistics_rate_cards_vendor_id_fkey FOREIGN KEY (vendor_id) REFERENCES public.logistics_vendors(id) ON DELETE CASCADE;


--
-- Name: logistics_vendors logistics_vendors_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.logistics_vendors
    ADD CONSTRAINT logistics_vendors_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: mcp_api_keys mcp_api_keys_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.mcp_api_keys
    ADD CONSTRAINT mcp_api_keys_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: mcp_billing mcp_billing_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.mcp_billing
    ADD CONSTRAINT mcp_billing_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: mcp_usage_log mcp_usage_log_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.mcp_usage_log
    ADD CONSTRAINT mcp_usage_log_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: messages messages_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES public.contacts(id);


--
-- Name: messages messages_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id);


--
-- Name: messages messages_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: order_items order_items_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;


--
-- Name: order_items order_items_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id);


--
-- Name: orders orders_assigned_to_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_assigned_to_fkey FOREIGN KEY (assigned_to) REFERENCES public.users(id);


--
-- Name: orders orders_buyer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_buyer_id_fkey FOREIGN KEY (buyer_id) REFERENCES public.contacts(id);


--
-- Name: orders orders_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: products products_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: prompt_registry prompt_registry_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.prompt_registry
    ADD CONSTRAINT prompt_registry_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: prompt_registry prompt_registry_fallback_prompt_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.prompt_registry
    ADD CONSTRAINT prompt_registry_fallback_prompt_id_fkey FOREIGN KEY (fallback_prompt_id) REFERENCES public.prompt_registry(id);


--
-- Name: shipment_events shipment_events_shipment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.shipment_events
    ADD CONSTRAINT shipment_events_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipments(id) ON DELETE CASCADE;


--
-- Name: shipments shipments_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.shipments
    ADD CONSTRAINT shipments_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id);


--
-- Name: shipments shipments_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.shipments
    ADD CONSTRAINT shipments_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: user_sessions user_sessions_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.user_sessions
    ADD CONSTRAINT user_sessions_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: user_sessions user_sessions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.user_sessions
    ADD CONSTRAINT user_sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: users users_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: workflow_steps workflow_steps_workflow_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.workflow_steps
    ADD CONSTRAINT workflow_steps_workflow_id_fkey FOREIGN KEY (workflow_id) REFERENCES public.workflows(id) ON DELETE CASCADE;


--
-- Name: workflows workflows_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.workflows
    ADD CONSTRAINT workflows_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id);


--
-- Name: workflows workflows_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.workflows
    ADD CONSTRAINT workflows_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: DATABASE neondb; Type: ACL; Schema: -; Owner: neondb_owner
--

GRANT ALL ON DATABASE neondb TO neon_superuser;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: cloud_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE cloud_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO neon_superuser WITH GRANT OPTION;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: cloud_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE cloud_admin IN SCHEMA public GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLES TO neon_superuser WITH GRANT OPTION;


--
-- PostgreSQL database dump complete
--

\unrestrict Vhe4BW7wvGKm3ncpn6rMXQeMtmIYtgViBtaKmz8NEsKbdBx0RCNNCmPOQGyE4zJ

