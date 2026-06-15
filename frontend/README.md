# TradeOS — Agentic AI Export Operating System

![TradeOS Vision](https://img.shields.io/badge/Status-MVP_Phase-blue?style=for-the-badge) ![React](https://img.shields.io/badge/React-18.x-blue?style=for-the-badge&logo=react) ![Vite](https://img.shields.io/badge/Vite-5.x-purple?style=for-the-badge&logo=vite)

**TradeOS** is an AI-native operational infrastructure and workflow orchestration platform built specifically for export and logistics SMEs. It aims to completely automate the complex, document-heavy global trade lifecycle by utilizing a sophisticated multi-agent AI workforce.

---

## 🌟 Core Philosophy & Vision

Global trade is historically bogged down by manual document verification, complex compliance rules, and siloed communication. TradeOS solves this by assigning specialized AI Agents to discrete nodes of the export supply chain. These agents orchestrate the workflow autonomously, escalating to human supervisors only when absolutely necessary.

### Key Pillars
- **AI Workforce**: Deploy specialized agents for documentation, compliance, and logistics.
- **Workflow Intelligence**: Live orchestration of shipments from PO intake to final delivery.
- **Compliance Automation**: Real-time screening against global trade restrictions (OFAC, DGFT, HS Codes).
- **Cloud Operations**: A single pane of glass to monitor throughput, latency, and success rates of the autonomous operations.

---

## 🚀 Key Modules & Features

1. **Secure Authentication**: JWT-based login system with Google SSO integration, automatic URL token capture, and a robust API interceptor (`apiFetch`) to securely inject sessions into every request.
2. **Operational Dashboard**: A high-level command center displaying active shipments, generated documents, compliance success rates, and overall AI throughput.
3. **Workflow Engine**: A dynamic, visual pipeline tracking active shipments. It provides a node-by-node breakdown of autonomous execution and simulated agent logs.
4. **Agent Hub**: A management grid for your AI workforce. Monitor the current tasks, daily throughput, and specialized skills of each agent.
5. **Documents Repository**: A sleek file-explorer interface housing all AI-generated trade documentation with clear statuses.
6. **Logistics Tracking**: Real-time freight visibility showing vessel progress from Port of Loading to Port of Discharge.
7. **Bilingual RTL Support**: Full Arabic language localization support with dynamic UI direction flipping (LTR ↔ RTL) and Google Translate integrations.
8. **Responsive Mobile Drawer**: A mobile-optimized slide-out hamburger navigation menu that hosts core links and localization toggles.
9. **Anti-Scraping Widget**: A floating WhatsApp chat widget engineered to obfuscate phone numbers from web scrapers via Base64 encoding.
10. **Responsive Auto-Scaling**: Fluid, layout-aware UI architecture utilizing CSS `clamp()` and native scroll handling to prevent overflow clipping across mobile, tablet, and short-landscape viewports.
11. **Live PDF PO Extraction**: Upload Purchase Order PDFs directly to the dashboard to instantly extract data and trigger the autonomous `po-to-dispatch` AI pipeline.

---

## 🛠 Technical Architecture

The frontend is built for speed, maintainability, and visual excellence.

* **Framework**: React 18
* **Build Tool**: Vite (for lightning-fast HMR and optimized production builds)
* **Routing**: React Router DOM v6
* **State Management**: Zustand (for lightweight global state)
* **Styling**: Premium Vanilla CSS. We utilize native CSS variables, glassmorphism (backdrop filters), and hardware-accelerated CSS micro-animations.
* **UI/UX Libraries**: 
  * `framer-motion` (for physics-based page transitions and component animations)
  * `lucide-react` (for consistent vector iconography)
  * `sonner` (for native, animated toast notifications)
  * `recharts` (for elegant data visualization)

### Project Structure
```text
/src
 ├── /components      # Reusable UI elements (WhatsAppWidget, MetricCards)
 ├── /layouts         # App layout wrappers (MainLayout, ProtectedRoute)
 ├── /pages           # Core module views (Login, Dashboard, Agent Hub)
 ├── /store           # Zustand global state (useAppStore for auth & lang)
 ├── App.jsx          # React Router configuration
 └── index.css        # Premium CSS design tokens and variables
```

---

## 🔌 API Integration & Endpoints (Swagger)

While this repository contains the frontend MVP, it is designed to interface with a robust backend AI orchestration engine. The backend architecture is documented via an OpenAPI (Swagger) specification. 

You can find the complete API schema in the `swagger.yaml` file located in the root directory. 

### Core Endpoints

* `POST /api/v1/auth/login`: Handles secure user authentication.
* `GET /api/v1/agents`: Retrieves the real-time status, throughput metrics, and active tasks of all deployed AI agents. 
* `GET /api/v1/workflows/{shipmentId}`: Fetches the step-by-step lifecycle status of a specific shipment.
* `GET /api/v1/documents`: Lists all generated trade documents along with their validation statuses and metadata.
* `POST /api/v1/approvals`: Fetches workflows waiting for Human-in-the-Loop review and allows the supervisor to approve/reject them.

---


## 🛣 Future Roadmap

- [ ] **WebSockets Integration**: Implement real-time Socket.io connections for live agent log streaming across all modules.
- [ ] **Advanced Data Export**: Allow CSV/PDF downloads of compliance and throughput audits.
