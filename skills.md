# skills.md — Agentic AI OS for Export Documentation

## Product Vision

Build an AI-native operating system for export/import SMEs that automates documentation, compliance, communication, shipment coordination, and operational workflows using autonomous AI agents. AI agents and employees collaborate from the same projects, conversations, and files, governed centrally and connected to existing enterprise systems.

Target Market:
• Exporters
• Freight forwarders
• Customs brokers
• Trading companies
• GCC import/export SMEs
• Logistics companies

Primary Regions:
• India
• UAE
• Saudi Arabia
• Qatar
• Oman

---

# Core Philosophy

Traditional ERP:
Human operates software.

Agentic AI OS:
AI operates workflows while humans supervise.

Goal:
Reduce operational dependency on manual staff, fragmented systems, and repetitive documentation tasks.

---

# Core Business Problems

## Current Industry Pain Points

• Manual export documentation
• Repeated data entry
• WhatsApp-based operations
• Human dependency
• Compliance mistakes
• Shipment visibility issues
• Delayed customer communication
• Non-standard workflows
• Multi-language coordination problems
• No centralized intelligence layer

---

# Product Modules

## 1. AI Communication Layer

### Features

• WhatsApp AI assistant
• Email parsing
• Voice command processing
• Arabic-English translation
• Document intake automation
• AI-based customer communication

### Skills Required

• WhatsApp Business API
• Twilio
• Email IMAP/SMTP parsing
• OCR pipelines
• Speech-to-text
• Translation models
• NLP pipelines

---

## 2. Export Documentation Agent

### Responsibilities

• Commercial invoice generation
• Packing list generation
• HS code suggestions
• COO document preparation
• Shipping bill assistance
• BL validation
• Insurance documentation
• LC document preparation

### AI Skills

• Document intelligence
• Structured extraction
• Template generation
• Multi-document consistency validation
• Compliance reasoning

### Technical Skills

• OCR
• LayoutLM
• Vision models
• RAG pipelines
• LLM orchestration
• PDF generation
• Workflow engines

---

## 3. Logistics Coordination Agent

### Responsibilities

• Shipment tracking
• Freight coordination
• Container status updates
• Delivery ETA prediction
• Vendor coordination

### Integrations

• Shipping APIs
• Freight systems
• Email automation
• WhatsApp workflows

### Skills Required

• API integrations
• Event-driven systems
• Async workflow orchestration

---

## 4. Compliance Agent

### Responsibilities

• HS code validation
• Customs rule checking
• Export regulation awareness
• Country-specific compliance verification
• GST/LUT validation

### AI Skills

• Regulatory RAG systems
• Rule-based reasoning
• Semantic search
• Knowledge graphs

### Data Sources

• DGFT
• ICEGATE
• Customs regulations
• GCC import rules

---

## 5. Finance Agent

### Responsibilities

• Invoice matching
• LC verification
• Payment reminders
• Export finance tracking
• Credit risk alerts

### Skills Required

• ERP integrations
• Financial workflows
• AI anomaly detection
• Accounting automation

---

## 6. Operations Intelligence Layer

### Responsibilities

• Shipment analytics
• Delay prediction
• Employee productivity tracking
• Customer risk scoring
• Revenue insights

### Skills Required

• BI systems
• AI analytics
• Forecasting models
• Dashboard systems

---

# AI Architecture

## Core Stack

### LLM Layer

• OpenAI
• Claude
• Gemini
• Local LLM fallback

### Agent Framework

• LangGraph
• CrewAI
• AutoGen
• Temporal workflows

### Orchestration

• n8n
• Temporal
• Airflow

### Memory Layer

• Vector databases
• PostgreSQL
• Redis

### Retrieval Layer

• RAG pipelines
• Semantic search
• Knowledge indexing

### OCR Layer

• PaddleOCR
• Tesseract
• Azure Document Intelligence
• AWS Textract

---

# Multi-Agent System Design

## Agent Types

### Documentation Agent

Handles export documents.

### Communication Agent

Handles email/WhatsApp/customer interaction.

### Compliance Agent

Handles regulatory reasoning.

### Logistics Agent

Handles shipment coordination.

### Finance Agent

Handles accounting and payment workflows.

### Supervisor Agent

Monitors all workflows and escalations.

---

# Human-in-the-Loop System

## Required Features

• Approval checkpoints
• Escalation workflows
• Confidence scoring
• Manual override capability
• Audit logging
• Version tracking

---

# Cloud Infrastructure

## Deployment Philosophy

Thin-client workforce model:
Minimal employee device complexity.

Everything runs in centralized cloud infrastructure.

---

## Infrastructure Stack

### Cloud Providers

• AWS
• Azure
• GCP

### Backend

• FastAPI
• Node.js
• gRPC microservices

### Frontend

• Next.js
• React
• Role-based dashboards

### Databases

• PostgreSQL
• Redis
• Elasticsearch

### Messaging

• Kafka
• RabbitMQ
• NATS

### Authentication

• Keycloak
• Auth0
• SSO integration

---

# Security Architecture

## Requirements

• Role-based access control
• Zero-trust architecture
• Audit logs
• Encryption at rest
• Encryption in transit
• Remote session management
• Device restrictions
• Data isolation

---

# AI Workflow Lifecycle

## Example Workflow

### Step 1

Customer sends PO via WhatsApp.

### Step 2

Communication Agent extracts order data.

### Step 3

Documentation Agent generates:
• invoice
• packing list
• shipping draft

### Step 4

Compliance Agent validates:
• HS code
• export rules
• country restrictions

### Step 5

Finance Agent validates payment terms.

### Step 6

Supervisor Agent requests human approval.

### Step 7

AI sends documents automatically.

### Step 8

Logistics Agent tracks shipment.

### Step 9

Customer receives automated updates.

---

# Industry Integrations

## ERP Integrations

• Tally
• Zoho Books
• Odoo
• SAP Business One

## Logistics Integrations

• DHL
• FedEx
• Maersk APIs

## Communication Integrations

• WhatsApp
• Gmail
• Outlook
• Slack

---

# GCC Localization Requirements

## Language Support

• English
• Arabic
• Hindi
• Malayalam

## Business Considerations

• GCC invoicing styles
• VAT workflows
• Arabic document formatting
• Regional trade practices

---

# MVP Scope

## Phase 1

### Core Features

• WhatsApp order intake
• AI invoice generation
• Packing list automation
• Shipment tracking dashboard
• Human approval workflows

### Goal

Replace manual documentation staff workload by 50%.


