import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import './LandingPage.css';

export default function LandingPage() {
  const [activeModal, setActiveModal] = useState(null);
  const [isZoomed, setIsZoomed] = useState(false);

  useEffect(() => {
    if (activeModal) {
      document.body.style.overflow = 'hidden';
    } else {
      document.body.style.overflow = '';
    }
    return () => { document.body.style.overflow = ''; };
  }, [activeModal]);

  useEffect(() => {
    const reveals = document.querySelectorAll('.reveal');
    const obs = new IntersectionObserver((entries) => {
      entries.forEach((e, i) => {
        if (e.isIntersecting) {
          setTimeout(() => e.target.classList.add('in-view'), i * 60);
          obs.unobserve(e.target);
        }
      });
    }, { threshold: 0.1, rootMargin: '0px 0px -40px 0px' });

    reveals.forEach(el => obs.observe(el));

    return () => {
      obs.disconnect();
    };
  }, []);

  return (
    <div className="landing-page-wrapper">
      {/* NAV */}
      <nav>
        <a href="#top" onClick={(e) => { e.preventDefault(); const wrapper = document.querySelector('.landing-page-wrapper'); if (wrapper) wrapper.scrollTo({ top: 0, behavior: 'smooth' }); }} className="nav-logo">TradeOS<span className="dot"><img src="logo.jpeg" alt="TradeOS" width="50"
          height="50" /></span></a>
        <ul className="nav-links">
          <li><a href="#problem">The Problem</a></li>
          <li><a href="#features">Platform</a></li>
          <li><a href="#how">How It Works</a></li>
          <li><a href="#pricing">Pricing</a></li>
          <li><a href="https://demo.exportagent.online" className="nav-cta" target="_blank" rel="noopener noreferrer">Live Demo →</a></li>
        </ul>
      </nav>

      {/* HERO */}
      <section className="hero" id="top">
        <div className="hero-grid-bg"></div>
        <div className="hero-left">
          <p className="hero-eyebrow">Global Trade Corridors</p>
          <h1 className="hero-h1"><em>Transforming</em> Fragmented Trade Operations into <em>intelligent</em> export
            operations
          </h1>
          <p className="hero-sub">TradeOS is an <b>honest</b> agentic AI operating system for export houses and freight forwarders. Automate
            PO processing, documentation, HS validation, and shipment coordination — while you stay in control. It works as
            your digital employees extending to your human teams' intelligent assistant, seamlessly integrating with
            your organization's existing workflows.</p>
          <p className="hero-sub"><b>TradeOS Community Edition</b> gives businesses a privacy-first, local AI operational environment that runs directly on their own AI PC or infrastructure. Customers can use OpenClaw / AgentOS with local workflows, local OCR, local LLMs, local RAG knowledge systems, local agents, and secure local file processing — without needing to upload sensitive operational data to external cloud platforms.</p>

          <p className="hero-sub">The free local platform enables organizations to build AI-assisted operational workflows while maintaining full control over their documents, shipment records, communication history, and internal business processes. Customers can optionally connect their local AgentOS to TradeOS cloud MCP services for advanced trade intelligence, compliance assistance, freight intelligence, and specialized export workflow capabilities.</p>
          <br /><small>Active development going on for pilot programs</small>
          <div className="hero-ctas">
            <a href="https://demo.exportagent.online" className="btn-primary" target="_blank" rel="noopener noreferrer">Try the Live Demo &rarr;</a>
            <a href="#how" className="btn-secondary">See how it works</a>
          </div>
          <div className="hero-trust">
            <span>Enterprise ready</span>
            <span className="hero-trust-divider"></span>
            <span>Human-in-the-loop design</span>
            <span className="hero-trust-divider"></span>
            <span>Beta pilot active</span>
          </div>
        </div>
        <div className="hero-right">
          <div className="terminal">
            <div className="terminal-bar">
              <div className="terminal-dot red"></div>
              <div className="terminal-dot yellow"></div>
              <div className="terminal-dot green"></div>
              <span className="terminal-title">tradeos — export-agent</span>
            </div>
            <div className="terminal-body">
              <div className="t-dim">// Processing PO from International buyer</div><br />
              <span className="t-accent">▶</span> <span className="t-white">Parsing order...</span><br />
              <span className="t-green">✓</span> <span className="t-white">Extracted: 1000 units Industrial Widgets</span><br />
              <span className="t-green">✓</span> <span className="t-white">Buyer: Acme Corporation, Global</span><br />
              <br />
              <span className="t-accent">▶</span> <span className="t-white">HS Code validation</span><br />
              <span className="t-green">✓</span> <span className="t-blue">8479.89.90</span> <span className="t-dim">— Mechanical appliances,
                confidence 98%</span><br />
              <br />
              <span className="t-accent">▶</span> <span className="t-white">Generating shipping invoice...</span><br />
              <span className="t-yellow">⚑</span> <span className="t-white">Awaiting your approval before submit</span><br />
              <br />
              <span className="t-dim">─────────────────────────────────</span><br />
              <span className="t-green">✓ Draft ready</span> <span className="t-white">· Your CHA reviews &amp; signs</span><br />
              <br />
              <span className="t-accent">&gt;</span> <span className="t-white"><span className="t-cursor"></span></span>
            </div>
          </div>
          <div className={`terminal-caption ${isZoomed ? 'zoomed' : ''}`} onClick={() => setIsZoomed(!isZoomed)}>
            <div className="terminal-caption-inner">
              <div className="redact-pill"></div>
              <img src="PO-auto-processing.png" alt="WhatsApp PO Processing" width="100%" height="auto" />
            </div>
          </div>
        </div>
      </section>

      {/* STAT BAR */}
      <div className="stat-bar">
        <div className="marquee-track">
          <span className="marquee-item marquee-sep">◆</span>
          <span className="marquee-item"><strong>Kerala</strong> pilot: Kochi · Kozhikode · Trivandrum</span>
          <span className="marquee-item marquee-sep">◆</span>
          <span className="marquee-item"><strong>₹20k–60k</strong> per shipment — pain is real</span>
        </div>
      </div>

      {/* PROBLEM */}
      <section className="problem-section" id="problem">
        <div className="section-inner">
          <p className="section-label reveal">The Problem</p>
          <h2 className="section-h2 reveal">Export SMEs are running<br /><em>billion-dollar corridors</em><br />on WhatsApp threads
          </h2>
          <div className="problem-grid">
            <div>
              <p className="section-body reveal">Every export house you know is coordinating shipments via WhatsApp groups,
                tracking orders on Excel sheets, and relying on senior staff who carry all the knowledge in their heads. One
                wrong HS code costs real money. One missed document stalls a shipment at customs.</p>
              <p className="section-body reveal" style={{ marginTop: '1rem' }}>Enterprise platforms like Flexport exist — but they're
                built for large shippers. The 10–100 person export house is genuinely underserved. Until now.</p>
              <p className="section-body reveal" style={{ marginTop: '1rem' }}><b>TradeOS does NOT vanish all costs. It makes them cheaper and faster to manage.</b> Your CHA still does their job. Your forwarder still does their job. But neither of them is waiting on you anymore, and neither of them is cleaning up your HS code mistakes.</p>
              <p className="section-body reveal" style={{ marginTop: '1rem' }}>TradeOS doesn't make the ₹20k–₹60k disappear. It compresses the doc prep cost, prevents the error cost (which is the most dangerous variable), and makes the CHA and forwarder's job faster — which over time creates pricing leverage with them. <b>The real saving is in the ₹3k–₹18k range per shipment in staff time + error prevention, plus the compounding benefit of never having a ₹50k+ detention surprise.</b></p>
            </div>
            <div className="vs-stack reveal">
              <div className="vs-card before">
                <span className="vs-tag before-tag">Before TradeOS</span>
                <ul className="vs-list">
                  <li data-icon="⚡">WhatsApp floods with unstructured POs from buyers</li>
                  <li data-icon="⚡">Senior staff manually decode and re-type into Excel</li>
                  <li data-icon="⚡">HS codes guessed or looked up individually per shipment</li>
                  <li data-icon="⚡">Documentation errors caught at customs — too late</li>
                  <li data-icon="⚡">Knowledge locked in one person's head</li>
                </ul>
              </div>
              <div className="vs-card after">
                <span className="vs-tag after-tag">With TradeOS</span>
                <ul className="vs-list">
                  <li data-icon="✓">PO parsed automatically from WhatsApp / email</li>
                  <li data-icon="✓">Structured workflows replace manual re-keying</li>
                  <li data-icon="✓">HS codes validated with 98%+ accuracy + rule engine</li>
                  <li data-icon="✓">Draft documents ready for your CHA to review &amp; approve</li>
                  <li data-icon="✓">Operations run even when key staff are unavailable</li>
                </ul>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* FEATURES */}
      <section className="features-section" id="features">
        <div className="section-inner">
          <div className="features-header">
            <p className="section-label reveal">Platform Capabilities</p>
            <h2 className="section-h2 reveal">Operational intelligence,<br /><em>not just dashboards</em></h2>
            <p className="section-body reveal">Most export SaaS is forms and tables. TradeOS is a multi-agent workflow system
              that reasons about your shipment from PO to port — with a human approval at every critical step.</p>
          </div>
          <div className="features-grid reveal">
            <div className="feat-card">
              <div className="feat-icon orange">📄</div>
              <h3 className="feat-h3">PO Processing</h3>
              <p className="feat-p">Parse purchase orders from WhatsApp messages, PDFs, or emails. Structured data extracted
                instantly — product, quantity, destination, Incoterms.</p>
            </div>
            <div className="feat-card">
              <div className="feat-icon green">✅</div>
              <h3 className="feat-h3">HS Code Validation</h3>
              <p className="feat-p">AI-assisted HS classification with local rule engine for standard codes. Complex cases
                escalated to LLM reasoning. Confidence score on every lookup.</p>
            </div>
            <div className="feat-card">
              <div className="feat-icon blue">🧾</div>
              <h3 className="feat-h3">Document Generation</h3>
              <p className="feat-p">Commercial invoices, packing lists, shipping bills — drafted automatically.
                Human-in-the-loop approval before any document is submitted.</p>
            </div>
            <div className="feat-card">
              <div className="feat-icon orange">💬</div>
              <h3 className="feat-h3">WhatsApp Integration</h3>
              <p className="feat-p">Meet your operators where they work. Shipment updates, approvals, and alerts delivered
                through WhatsApp — no new app to learn.</p>
            </div>
            <div className="feat-card">
              <div className="feat-icon green">⚖️</div>
              <h3 className="feat-h3">Compliance Assist</h3>
              <p className="feat-p">FTP 2023 requirements, CEPA rules-of-origin, LC analysis. AI flags issues; your licensed CHA
                or customs broker makes the final call.</p>
            </div>
            <div className="feat-card">
              <div className="feat-icon blue">📊</div>
              <h3 className="feat-h3">Shipment Intelligence</h3>
              <p className="feat-p">Track shipment status, freight rate benchmarks, and compliance patterns across your
                portfolio. Data compounds with every shipment.</p>
            </div>
          </div>
        </div>
      </section>

      {/* HOW IT WORKS */}
      <section className="how-section" id="how">
        <div className="section-inner">
          <p className="section-label reveal">How It Works</p>
          <h2 className="section-h2 reveal">From buyer message<br />to <em>port-ready</em> shipment</h2>
          <div className="how-steps reveal">
            <div className="how-step">
              <span className="step-num">01 — RECEIVE</span>
              <h3 className="step-h3">Buyer sends PO via WhatsApp or email</h3>
              <p className="step-p">TradeOS captures the unstructured message. OCR pipeline extracts product, qty, specs,
                destination, and terms.</p>
              <span className="step-arrow">›</span>
            </div>
            <div className="how-step">
              <span className="step-num">02 — VALIDATE</span>
              <h3 className="step-h3">AI validates HS codes &amp; compliance checks</h3>
              <p className="step-p">Multi-agent workflow cross-checks HS code, CEPA origin rules, and document requirements.
                Flags any issues for human review.</p>
              <span className="step-arrow">›</span>
            </div>
            <div className="how-step">
              <span className="step-num">03 — DRAFT</span>
              <h3 className="step-h3">Documents generated, awaiting approval</h3>
              <p className="step-p">Commercial invoice, packing list, and shipping bill drafted. Operator receives approval
                request — nothing is submitted without a human sign-off.</p>
              <span className="step-arrow">›</span>
            </div>
            <div className="how-step">
              <span className="step-num">04 — SHIP</span>
              <h3 className="step-h3">Your CHA submits; TradeOS tracks</h3>
              <p className="step-p">Licensed CHA reviews, approves, and submits. TradeOS monitors shipment status and builds
                your export intelligence database.</p>
            </div>
          </div>
        </div>
      </section>

      {/* CORRIDORS */}
      <section className="corridors-section" id="corridors">
        <div className="section-inner">
          <div className="corridor-layout">
            <div>
              <p className="section-label reveal">Trade Corridors</p>
              <h2 className="section-h2 reveal">Built for <em>Global</em> trade realities</h2>
              <p className="section-body reveal">Starting with North America's dense freight network, then expanding to European and
                APAC port clusters. Regional operator onboarding begins Month 9.</p>
            </div>
            <div className="trade-pills reveal">
              <div className="trade-pill">
                <span className="trade-flag">🇮🇳 🇦🇪</span>
                <div className="trade-info">
                  <div className="trade-name">Kerala → UAE</div>
                  <div className="trade-sub">Kochi / Tuticorin → Jebel Ali / Dubai</div>
                  <div className="trade-sub">Spices · Sea Food · Coffee · Tea · Rice · Ayurvedic · Electronics · Machinery · Textiles · Automotive</div>
                </div>
                <span className="trade-badge active">Pilot Active</span>
              </div>
              <div className="trade-pill">
                <span className="trade-flag">🇮🇳 🇸🇦</span>
                <div className="trade-info">
                  <div className="trade-name">Kerala → Saudi Arabia</div>
                  <div className="trade-sub">Kochi → Dammam / Jeddah</div>
                  <div className="trade-sub">Agriculture · Pharmaceuticals · Consumer Goods</div>
                </div>
                <span className="trade-badge active">Pilot Active</span>
              </div>
              <div className="trade-pill">
                <span className="trade-flag">🇮🇳 🇰🇼</span>
                <div className="trade-info">
                  <div className="trade-name">Kerala → Kuwait</div>
                  <div className="trade-sub">Kochi → Shuwaikh Port</div>
                  <div className="trade-sub">Port-cluster expansion · Phase 2</div>
                </div>
                <span className="trade-badge active">Pilot Active</span>
              </div>
              <div className="trade-pill">
                <span className="trade-flag">🇮🇳 🇧🇭</span>
                <div className="trade-info">
                  <div className="trade-name">Kerala → Bahrain</div>
                  <div className="trade-sub">Kochi → Khalifa Bin Salman Port</div>
                  <div className="trade-sub">Regional import brokers · Multilingual ops</div>
                </div>
                <span className="trade-badge active">Pilot Active</span>
              </div>
              <div className="trade-pill">
                <span className="trade-flag">🇮🇳</span>
                <div className="trade-info">
                  <div className="trade-name">India → APAC & Africa Trade Corridors</div>
                  <div className="trade-sub">Chennai / Mangalore / Tuticorin → GCC Ports</div>
                  <div className="trade-sub">Regional import brokers · Multilingual ops</div>
                </div>
                <span className="trade-badge">Phase 2 — 2028</span>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* PRICING */}
      <section className="pricing-section" id="pricing">
        <div className="section-inner">
          <p className="section-label reveal">Pricing</p>
          <h2 className="section-h2 reveal">Start free. Scale when you <em>trust the platform</em> as our <em>Operational AI Partner</em>.</h2>
          <p className="section-body reveal">No setup fees during the pilot phase. If verified as a pilot partner, you get your first 10 shipments completely free (limited to 5 partners) — so you can see the value before you pay.</p>
          <div className="pricing-grid reveal">
            <div className="price-card">
              <div className="price-head">
                <div className="price-label">Starter (≤10 shipments)</div>
                <div className="price-amount">₹15k – ₹20k</div>
                <div className="price-unit">per month · ₹1,500 – ₹2,000 / shipment</div>
              </div>
              <div className="price-body">
                <ul className="price-features">
                  <li>TradeOS Community Edition FREE</li>
                  <li>Up to 10 shipments/month</li>
                  <li>Full PO processing pipeline</li>
                  <li>HS code validation</li>
                  <li>Document generation</li>
                  <li>WhatsApp integration</li>
                  <li>Human-in-the-loop approvals</li>
                </ul>
                <details className="price-breakdown">
                  <summary>View Cost Breakdown</summary>
                  <div className="breakdown-content">
                    <div className="bd-row"><span>Current Ops Cost</span><span>~₹20k - ₹60k</span></div>
                    <div className="bd-subrow"><span>• CHA/Customs</span><span>₹3.5k–₹8k</span></div>
                    <div className="bd-subrow"><span>• Freight Forwarding</span><span>₹5k–₹15k</span></div>
                    <div className="bd-subrow"><span>• Port Handling</span><span>₹8k–₹15k</span></div>
                    <div className="bd-subrow"><span>• Doc Prep</span><span>₹3k–₹8k</span></div>
                    <div className="bd-subrow"><span>• Errors/Rework</span><span>₹2k–₹10k</span></div>
                    <div className="bd-divider"></div>
                    <div className="bd-row highlight"><span>TradeOS Cost</span><span>₹1.5k–₹2k</span></div>
                    <div className="bd-savings">Save up to 95% on direct documentation and ops coordination costs per shipment.</div>
                  </div>
                </details>
                <Link to="/login" className="price-cta solid">Try Demo</Link>
              </div>
            </div>
            <div className="price-card">
              <div className="price-head">
                <div className="price-label">Growth (11–30/month)</div>
                <div className="price-amount">₹25k – ₹40k</div>
                <div className="price-unit">per month · ₹1,000 – ₹1,600 / shipment</div>
              </div>
              <div className="price-body">
                <ul className="price-features">
                  <li>11-30 shipments/month</li>
                  <li>Everything in Starter</li>
                  <li>Multi-user access</li>
                  <li>Compliance alerts</li>
                  <li>Dedicated onboarding support</li>
                </ul>
                <details className="price-breakdown">
                  <summary>View Cost Breakdown</summary>
                  <div className="breakdown-content">
                    <div className="bd-row"><span>Current Ops Cost</span><span>~₹20k - ₹60k</span></div>
                    <div className="bd-subrow"><span>• CHA/Customs</span><span>₹3.5k–₹8k</span></div>
                    <div className="bd-subrow"><span>• Freight Forwarding</span><span>₹5k–₹15k</span></div>
                    <div className="bd-subrow"><span>• Port Handling</span><span>₹8k–₹15k</span></div>
                    <div className="bd-subrow"><span>• Doc Prep</span><span>₹3k–₹8k</span></div>
                    <div className="bd-subrow"><span>• Errors/Rework</span><span>₹2k–₹10k</span></div>
                    <div className="bd-divider"></div>
                    <div className="bd-row highlight"><span>TradeOS Cost</span><span>₹1k–₹1.6k</span></div>
                    <div className="bd-savings">At ~₹1,300/shipment vs ₹20k ops cost, realize a 15-45x ROI on your subscription.</div>
                  </div>
                </details>
                <a href="mailto:info@exportagent.online" className="price-cta outline">Contact Sales</a>
              </div>
            </div>
            <div className="price-card">
              <div className="price-head">
                <div className="price-label">Freight ops (30+/month)</div>
                <div className="price-amount">₹50k – ₹1L</div>
                <div className="price-unit">per month · ₹700 – ₹1,200 / shipment</div>
              </div>
              <div className="price-body">
                <ul className="price-features">
                  <li>30+ shipments/month</li>
                  <li>Everything in Growth</li>
                  <li>Freight intelligence module</li>
                  <li>GCC multilingual operations</li>
                  <li>ERP / bank integrations</li>
                  <li>Custom workflow modules</li>
                </ul>
                <details className="price-breakdown">
                  <summary>View Cost Breakdown</summary>
                  <div className="breakdown-content">
                    <div className="bd-row"><span>Current Ops Cost</span><span>~₹20k - ₹60k</span></div>
                    <div className="bd-subrow"><span>• CHA/Customs</span><span>₹3.5k–₹8k</span></div>
                    <div className="bd-subrow"><span>• Freight Forwarding</span><span>₹5k–₹15k</span></div>
                    <div className="bd-subrow"><span>• Port Handling</span><span>₹8k–₹15k</span></div>
                    <div className="bd-subrow"><span>• Doc Prep</span><span>₹3k–₹8k</span></div>
                    <div className="bd-subrow"><span>• Errors/Rework</span><span>₹2k–₹10k</span></div>
                    <div className="bd-divider"></div>
                    <div className="bd-row highlight"><span>TradeOS Cost</span><span>₹700–₹1.2k</span></div>
                    <div className="bd-savings">Maximum volume efficiency for enterprise freight forwarders.</div>
                  </div>
                </details>
                <a href="mailto:info@exportagent.online" className="price-cta outline">Contact Sales</a>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* DEMO CALLOUT */}
      <section className="demo-section">
        <div className="section-inner">
          <div className="demo-inner">
            <div className="demo-text">
              <h2 className="demo-h2 reveal">See TradeOS in action</h2>
              <p className="reveal">The live demo at <strong>exportagent.online</strong> lets you experience the full export
                agent workflow — from parsing a buyer's WhatsApp message to generating a shipment-ready document set.</p>
            </div>
            <Link to="/login" className="demo-url reveal">
              exportagent.online <span className="arrow">↗</span>
            </Link>
          </div>
        </div>
      </section>

      {/* FOOTER */}
      <footer>
        <div className="section-inner">
          <div className="footer-inner">
            <div>
              <div className="footer-brand">TradeOS<span className="dot">.</span></div>
              <div className="footer-tagline">Agentic AI for India–GCC Export Operations</div>
            </div>
            <div className="footer-links">
              <h4>Platform</h4>
              <ul>
                <li><a href="#features">Features</a></li>
                <li><a href="#how">How it works</a></li>
                <li><a href="#pricing">Pricing</a></li>
                <li><a href="https://demo.exportagent.online" target="_blank" rel="noopener noreferrer">Live Demo</a></li>
              </ul>
            </div>
            <div className="footer-links">
              <h4>Knowledge Base</h4>
              <ul>
                <li><Link to="/how-it-works" target="_blank">Process Breakdown</Link></li>
                <li><Link to="/cost-breakdown" target="_blank">Cost Breakdown</Link></li>
              </ul>
            </div>
            <div className="footer-links">
              <h4>Focus Regions</h4>
              <ul>
                <li><a href="#" onClick={(e) => { e.preventDefault(); setActiveModal('uae'); }}>United Arab Emirates</a></li>
                <li><a href="#" onClick={(e) => { e.preventDefault(); setActiveModal('saudi'); }}>Saudi Arabia</a></li>
                <li><a href="#" onClick={(e) => { e.preventDefault(); setActiveModal('oman'); }}>Oman & Bahrain</a></li>
                <li><a href="#" onClick={(e) => { e.preventDefault(); setActiveModal('qatar'); }}>Qatar & Kuwait</a></li>
              </ul>
            </div>
            <div className="footer-links">
              <h4>Company</h4>
              <ul>
                <li><a href="#corridors">Trade Corridors</a></li>
                <li><a href="#" onClick={(e) => { e.preventDefault(); setActiveModal('contact'); }}>Contact</a></li>
                <li><a href="#" onClick={(e) => { e.preventDefault(); setActiveModal('privacy'); }}>Privacy Policy</a></li>
                <li><a href="#" onClick={(e) => { e.preventDefault(); setActiveModal('terms'); }}>Terms of Service</a></li>
              </ul>
            </div>
          </div>
          <div className="footer-bottom">
            <span className="footer-copy">© 2026 TradeOS. All rights reserved. Global Headquarters.</span>
            <span className="footer-compliance">TradeOS assists and automates — all documents require human approval before
              submission. Operational responsibility remains with the exporter. TradeOS is not a licensed customs or legal
              agent.</span>
          </div>
        </div>
      </footer>

      {/* MODALS */}
      {activeModal && (
        <div style={{
          position: 'fixed', top: 0, left: 0, right: 0, bottom: 0,
          background: 'rgba(0,0,0,0.8)', backdropFilter: 'blur(10px)',
          display: 'flex', justifyContent: 'center', alignItems: 'center',
          zIndex: 9999, padding: '1rem'
        }} onClick={() => setActiveModal(null)}>
          <div className="card animate-fade-in" style={{
            width: '100%', maxWidth: '700px', maxHeight: '90vh',
            display: 'flex', flexDirection: 'column',
            position: 'relative', border: '1px solid var(--border)',
            background: 'var(--paper)', color: 'var(--ink)',
            padding: 0, overflow: 'hidden', borderRadius: '8px'
          }} onClick={(e) => e.stopPropagation()}>

            {/* Header with Close Button */}
            <div style={{ display: 'flex', justifyContent: 'flex-end', padding: '1rem 1rem 0 0' }}>
              <button
                onClick={() => setActiveModal(null)}
                style={{ background: 'transparent', border: 'none', color: 'var(--ink-3)', cursor: 'pointer', fontSize: '2rem', lineHeight: '1', transition: 'color 0.2s', padding: '0.5rem' }}
                onMouseOver={e => e.currentTarget.style.color = 'var(--ink)'}
                onMouseOut={e => e.currentTarget.style.color = 'var(--ink-3)'}
              >
                &times;
              </button>
            </div>

            {/* Scrollable Content */}
            <div style={{ padding: '0 2.5rem 2.5rem 2.5rem', overflowY: 'auto', flex: 1 }}>

              {activeModal === 'contact' && (
                <div>
                  <h2 className="section-h2 mb-6" style={{ fontWeight: 700 }}>Contact Us</h2>

                  <h3 className="feat-h3 mb-3 mt-6" style={{ fontWeight: 600 }}>Get in Touch</h3>
                  <p className="section-body mb-4" style={{ lineHeight: '1.6' }}>TradeOS is currently collaborating with export houses, freight forwarders, customs brokers, and logistics SMEs across Kerala and GCC trade corridors to validate practical AI-assisted operational workflows.</p>
                  <p className="section-body mb-3" style={{ lineHeight: '1.6' }}>We welcome conversations regarding:</p>
                  <ul className="section-body mb-6" style={{ listStyleType: 'disc', paddingLeft: '1.5rem', lineHeight: '1.6' }}>
                    <li>pilot partnerships</li>
                    <li>export workflow automation</li>
                    <li>AI-assisted documentation</li>
                    <li>logistics workflow optimization</li>
                    <li>operational AI adoption</li>
                    <li>strategic collaborations</li>
                  </ul>

                  <h3 className="feat-h3 mb-3 mt-6" style={{ fontWeight: 600 }}>Contact Information</h3>
                  <p className="section-body mb-2" style={{ lineHeight: '1.6' }}><strong>Website:</strong> <a href="https://exportagent.online" target="_blank" rel="noreferrer" style={{ color: 'var(--accent)', textDecoration: 'none' }}>exportagent.online</a></p>
                  <p className="section-body mb-6" style={{ lineHeight: '1.6' }}><strong>Email:</strong> <a href="mailto:info@exportagent.online" style={{ color: 'var(--accent)', textDecoration: 'none' }}>info@exportagent.online</a></p>

                  <h3 className="feat-h3 mb-3 mt-6" style={{ fontWeight: 600 }}>Pilot Program</h3>
                  <p className="section-body mb-4" style={{ lineHeight: '1.6' }}>TradeOS is currently onboarding a limited number of pilot partners for supervised workflow validation and operational collaboration.</p>
                  <p className="section-body mb-3" style={{ lineHeight: '1.6' }}>Pilot programs focus on:</p>
                  <ul className="section-body mb-4" style={{ listStyleType: 'disc', paddingLeft: '1.5rem', lineHeight: '1.6' }}>
                    <li>purchase order processing</li>
                    <li>export documentation</li>
                    <li>shipment coordination</li>
                    <li>compliance assistance</li>
                    <li>AI-assisted operational workflows</li>
                  </ul>
                </div>
              )}

              {activeModal === 'terms' && (
                <div>
                  <h2 className="section-h2 mb-8" style={{ fontWeight: 700 }}>Terms of Service</h2>

                  <h3 className="feat-h3 mb-2">1. Introduction</h3>
                  <p className="section-body mb-6" style={{ lineHeight: '1.6' }}>TradeOS is an AI-assisted operational platform designed for export houses, freight forwarders, customs brokers, and logistics SMEs.<br /><br />By accessing or using TradeOS services, users agree to these Terms of Service.</p>

                  <h3 className="feat-h3 mb-2">2. Nature of Service</h3>
                  <p className="section-body mb-6" style={{ lineHeight: '1.6' }}>TradeOS provides workflow assistance, document processing support, operational automation, communication workflows, and AI-assisted export operations.<br /><br />TradeOS is not a licensed customs broker, legal advisor, or financial institution.</p>

                  <h3 className="feat-h3 mb-2">3. Human Approval Requirement</h3>
                  <p className="section-body mb-6" style={{ lineHeight: '1.6' }}>All AI-generated outputs, workflows, compliance recommendations, and documents must be reviewed and approved by authorized human operators before submission or operational use.<br /><br />TradeOS assists workflows but does not make autonomous legal, customs, or financial decisions.</p>

                  <h3 className="feat-h3 mb-2">4. User Responsibility</h3>
                  <p className="section-body mb-3" style={{ lineHeight: '1.6' }}>Users remain fully responsible for:</p>
                  <ul className="section-body mb-3" style={{ listStyleType: 'disc', paddingLeft: '1.5rem', lineHeight: '1.6' }}>
                    <li>export compliance</li>
                    <li>customs declarations</li>
                    <li>shipment accuracy</li>
                    <li>financial documentation</li>
                    <li>regulatory obligations</li>
                    <li>operational approvals</li>
                  </ul>
                  <p className="section-body mb-6" style={{ lineHeight: '1.6' }}>TradeOS acts solely as an operational assistance platform.</p>

                  <h3 className="feat-h3 mb-2">5. Limitation of Liability</h3>
                  <p className="section-body mb-6" style={{ lineHeight: '1.6' }}>TradeOS shall not be liable for operational losses, customs penalties, shipment delays, regulatory actions, or business decisions resulting from incorrect user input, third-party systems, or unapproved AI-generated outputs.</p>

                  <h3 className="feat-h3 mb-2">6. Intellectual Property</h3>
                  <p className="section-body mb-6" style={{ lineHeight: '1.6' }}>All TradeOS platform architecture, workflow logic, automation systems, branding, software components, and AI orchestration methodologies remain proprietary intellectual property of TradeOS.</p>

                  <h3 className="feat-h3 mb-2">7. Service Availability</h3>
                  <p className="section-body mb-6" style={{ lineHeight: '1.6' }}>TradeOS is currently under active development and pilot validation. Certain features, integrations, and workflows may evolve over time.</p>

                  <h3 className="feat-h3 mb-2">8. Governing Jurisdiction</h3>
                  <p className="section-body mb-6" style={{ lineHeight: '1.6' }}>These terms shall be governed by applicable laws and regulations of India.</p>
                </div>
              )}

              {activeModal === 'privacy' && (
                <div>
                  <h2 className="section-h2 mb-8" style={{ fontWeight: 700 }}>Privacy Policy</h2>

                  <h3 className="feat-h3 mb-2">1. Introduction</h3>
                  <p className="section-body mb-6" style={{ lineHeight: '1.6' }}>TradeOS values operational confidentiality, data privacy, and responsible AI usage.<br /><br />This Privacy Policy explains how operational and business information is collected, processed, and protected.</p>

                  <h3 className="feat-h3 mb-2">2. Information Collected</h3>
                  <p className="section-body mb-3" style={{ lineHeight: '1.6' }}>TradeOS may process:</p>
                  <ul className="section-body mb-6" style={{ listStyleType: 'disc', paddingLeft: '1.5rem', lineHeight: '1.6' }}>
                    <li>export documents</li>
                    <li>purchase orders</li>
                    <li>invoices</li>
                    <li>shipment details</li>
                    <li>operational communication data</li>
                    <li>workflow metadata</li>
                    <li>user account information</li>
                  </ul>

                  <h3 className="feat-h3 mb-2">3. Purpose of Data Usage</h3>
                  <p className="section-body mb-3" style={{ lineHeight: '1.6' }}>Collected information is used solely for:</p>
                  <ul className="section-body mb-6" style={{ listStyleType: 'disc', paddingLeft: '1.5rem', lineHeight: '1.6' }}>
                    <li>workflow automation</li>
                    <li>operational coordination</li>
                    <li>AI-assisted processing</li>
                    <li>compliance assistance</li>
                    <li>shipment tracking</li>
                    <li>platform improvement</li>
                  </ul>

                  <h3 className="feat-h3 mb-2">4. Data Security</h3>
                  <p className="section-body mb-3" style={{ lineHeight: '1.6' }}>TradeOS implements reasonable technical and operational safeguards including:</p>
                  <ul className="section-body mb-6" style={{ listStyleType: 'disc', paddingLeft: '1.5rem', lineHeight: '1.6' }}>
                    <li>role-based access controls</li>
                    <li>audit logging</li>
                    <li>cloud infrastructure security</li>
                    <li>controlled workflow approvals</li>
                  </ul>

                  <h3 className="feat-h3 mb-2">5. AI-Assisted Processing</h3>
                  <p className="section-body mb-6" style={{ lineHeight: '1.6' }}>Some operational data may be processed through AI models and third-party infrastructure providers solely for workflow execution and platform functionality.<br /><br />TradeOS aims to minimize unnecessary data exposure through OCR-first and cost-optimized workflow architectures.</p>

                  <h3 className="feat-h3 mb-2">6. Human-in-the-Loop Governance</h3>
                  <p className="section-body mb-6" style={{ lineHeight: '1.6' }}>TradeOS follows a supervised AI operational model where critical outputs require human review and approval before operational usage.</p>

                  <h3 className="feat-h3 mb-2">7. Third-Party Services</h3>
                  <p className="section-body mb-3" style={{ lineHeight: '1.6' }}>TradeOS may integrate with:</p>
                  <ul className="section-body mb-3" style={{ listStyleType: 'disc', paddingLeft: '1.5rem', lineHeight: '1.6' }}>
                    <li>cloud infrastructure providers</li>
                    <li>messaging services</li>
                    <li>AI model providers</li>
                    <li>storage systems</li>
                    <li>workflow orchestration platforms</li>
                  </ul>
                  <p className="section-body mb-6" style={{ lineHeight: '1.6' }}>Third-party services operate under their own policies and compliance standards.</p>

                  <h3 className="feat-h3 mb-2">8. Data Retention</h3>
                  <p className="section-body mb-6" style={{ lineHeight: '1.6' }}>Operational data may be retained for workflow continuity, audit purposes, system improvement, and regulatory support requirements.</p>

                  <h3 className="feat-h3 mb-2">9. Policy Updates</h3>
                  <p className="section-body mb-6" style={{ lineHeight: '1.6' }}>This Privacy Policy may be updated periodically as the platform evolves from pilot stage to production deployments.</p>

                  <h3 className="feat-h3 mb-2">10. Contact</h3>
                  <p className="section-body mb-6" style={{ lineHeight: '1.6' }}>For privacy or compliance-related questions:<br />✉ <a href="mailto:info@exportagent.online" style={{ color: 'var(--accent)', textDecoration: 'none' }}>info@exportagent.online</a><br />🌐 <a href="https://exportagent.online" target="_blank" rel="noreferrer" style={{ color: 'var(--accent)', textDecoration: 'none' }}>exportagent.online</a></p>
                </div>
              )}

              {activeModal === 'uae' && (
                <div>
                  <h2 className="section-h2 mb-6" style={{ fontWeight: 700 }}>United Arab Emirates</h2>
                  <p className="section-body mb-4" style={{ lineHeight: '1.6' }}>UAE is TradeOS's primary launch corridor. Dubai and Abu Dhabi together absorb the largest share of Kerala's spice, seafood, and textile exports. The UAE–India CEPA (2022) eliminated or reduced duties on 97% of Indian goods — creating a surge of new SME trade relationships that most export houses are still managing on WhatsApp. Dubai's re-export economy also means a single UAE buyer often distributes onward to 4–5 Gulf markets, making documentation accuracy critical from the first shipment.</p>
                </div>
              )}

              {activeModal === 'saudi' && (
                <div>
                  <h2 className="section-h2 mb-6" style={{ fontWeight: 700 }}>Saudi Arabia</h2>
                  <p className="section-body mb-4" style={{ lineHeight: '1.6' }}>KSA is the highest-volume GCC destination for Indian food exports — particularly rice, spices, ghee, and processed foods. Saudi Vision 2030 is accelerating import diversification away from oil-dependent procurement, opening new buyer categories for Kerala exporters. Halal certification is mandatory across almost all food product categories, and SABER product registration requirements add a compliance layer that catches unprepared exporters off-guard. TradeOS tracks both automatically.</p>
                </div>
              )}

              {activeModal === 'oman' && (
                <div>
                  <h2 className="section-h2 mb-6" style={{ fontWeight: 700 }}>Oman & Bahrain</h2>
                  <p className="section-body mb-4" style={{ lineHeight: '1.6' }}>Oman has a long-standing Kerala connection — the Malayali diaspora is among the largest expat communities in Muscat, driving consistent demand for food, textiles, and consumer goods. Bahrain operates as a smaller but highly accessible entry market, with a free trade zone structure that makes it attractive for first-time GCC exporters testing the corridor. Both markets have lighter regulatory overhead than UAE or KSA, making them ideal for pilot shipments while compliance workflows are being established.</p>
                </div>
              )}

              {activeModal === 'qatar' && (
                <div>
                  <h2 className="section-h2 mb-6" style={{ fontWeight: 700 }}>Qatar & Kuwait</h2>
                  <p className="section-body mb-4" style={{ lineHeight: '1.6' }}>Qatar's post-World Cup infrastructure boom has sustained elevated import demand, particularly for construction materials, food, and industrial goods. Kuwait remains one of the most stable GCC import markets with predictable buyer relationships — favoured by Kerala cashew, pepper, and cardamom exporters for repeat order reliability. Both markets require Arabic commercial documentation for customs clearance, a compliance step that frequently causes delays for export houses without proper tooling.</p>
                </div>
              )}

            </div>
          </div>
        </div>
      )}

    </div>
  );
}
