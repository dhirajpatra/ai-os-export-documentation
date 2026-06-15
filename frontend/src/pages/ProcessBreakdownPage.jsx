import React, { useState } from 'react';
import { Link } from 'react-router-dom';

const steps = [
  {
    num: "01",
    title: "Buyer sends PO via WhatsApp or email",
    badge: "does",
    badgeText: "TradeOS fully handles",
    summary: "This is where your ops team currently spends 2–4 hours of senior staff time per shipment. TradeOS eliminates almost all of it.",
    does: "Parses unstructured WhatsApp messages, PDFs, and emails. Extracts product name, quantity, unit, buyer details, Incoterms, and destination. Structures it into a clean, validated PO record — no re-typing.",
    doesNot: "You still need the buyer relationship. TradeOS only processes what comes in — it does not generate sales or negotiate terms.",
    saving: "Saves ~3–6 hrs senior staff time per shipment"
  },
  {
    num: "02",
    title: "HS code lookup and validation",
    badge: "does",
    badgeText: "TradeOS fully handles",
    summary: "One wrong HS code can trigger a customs hold costing ₹50,000+ in demurrage alone. This is where TradeOS pays for itself in one shipment.",
    does: "Validates HS code using local rule engine for standard Kerala exports (pepper: 0904.11.00, cardamom: 0908.31.00, seafood: Chapter 03, textiles: Chapter 61–63). Uses AI reasoning for complex or edge cases. Shows confidence score. Flags any mismatch before documents are drafted.",
    doesNot: "Final HS code confirmation is always signed off by your licensed CHA — TradeOS flags, drafts, and alerts. It is not a licensed customs agent and cannot make the final legal declaration.",
    saving: "Prevents ₹50k+ detention risk per error"
  },
  {
    num: "03",
    title: "Export document preparation",
    badge: "does",
    badgeText: "TradeOS fully handles",
    summary: "Commercial invoice, packing list, and shipping bill — currently drafted by hand or with Excel templates, often re-done multiple times when errors are found.",
    does: "Auto-generates commercial invoice, packing list, and shipping bill pre-filled from the validated PO. Checks for internal consistency (quantities match, values align, HS code present). Surfaces a clean draft for human review and approval — one-click HITL before anything is submitted.",
    doesNot: "The approved document still goes to your CHA for the actual customs filing on ICEGATE. TradeOS produces the draft; the licensed agent submits the legal declaration.",
    saving: "Eliminates 2–4 hrs doc prep per shipment"
  },
  {
    num: "04",
    title: "CHA / customs house agent filing",
    badge: "assists",
    badgeText: "TradeOS speeds this up",
    summary: "Your CHA is legally required and cannot be replaced by software. But how fast and cheap that service is depends entirely on how prepared you are when you hand it to them.",
    does: "Hands the CHA a complete, verified document package — correct HS code, clean invoice, accurate packing list, pre-checked for common errors. Reduces the CHA's working time on your shipment from 3–4 hrs to under 1 hr. Some CHAs offer lower rates to consistently well-prepared clients.",
    doesNot: "TradeOS cannot replace the CHA. The CHA holds the customs broker license (CBLR 2018), files on ICEGATE, liaises with the customs department, and carries legal accountability for the declaration. That is not changeable.",
    saving: "CHA spends less time = lower risk of rework charges"
  },
  {
    num: "05",
    title: "Compliance checks (CEPA, FSSAI, Spices Board)",
    badge: "assists",
    badgeText: "TradeOS assists",
    summary: "GCC-bound Kerala exports require multiple certifications — Spices Board for pepper/cardamom, FSSAI for food products, halal cert for many buyers, phytosanitary for plant products, and CEPA rules-of-origin for duty benefit.",
    does: "Flags which certificates are required for each product–destination combination. Tracks certificate status and expiry. Alerts when a required cert is missing before documents are finalised. For LC (Letter of Credit) shipments, highlights compliance clauses that need attention.",
    doesNot: "TradeOS does not apply for certificates on your behalf — you still engage Spices Board, FSSAI, and halal certifying bodies directly. We surface the requirement; you fulfil it.",
    saving: "Catches missing certs before port — not after"
  },
  {
    num: "06",
    title: "Freight booking and port coordination",
    badge: "no",
    badgeText: "Not our scope (yet)",
    summary: "Booking the vessel slot, coordinating the inland truck, container stuffing — this is physical logistics work done by your freight forwarder.",
    does: "In Phase 2: TradeOS will integrate freight rate intelligence so you can benchmark your forwarder's quote against market rates. Shipment tracking once the booking is made.",
    doesNot: "TradeOS does not book freight, manage container logistics, or replace the freight forwarder. Physical shipment coordination remains with your forwarder partner.",
    saving: "Phase 2: rate benchmarking saves negotiation time"
  },
  {
    num: "07",
    title: "Port handling and terminal fees",
    badge: "no",
    badgeText: "Not our scope",
    summary: "Terminal handling charges (₹8k–₹15k) are fixed port infrastructure fees. No software platform touches these.",
    does: "Nothing currently. The only indirect benefit: clean documentation means no inspection holds or delays that trigger demurrage (₹5k–10k/day). Fast clearance = no excess port storage fees.",
    doesNot: "TradeOS has zero impact on THC, container fees, or port operator charges. These are government and terminal rates.",
    saving: "Indirect: fast clearance avoids demurrage"
  }
];

export default function ProcessBreakdownPage() {
  const [openStep, setOpenStep] = useState(0);
  return (
    <div className="landing-page-wrapper" style={{paddingTop: '6rem', backgroundColor: 'var(--paper)', minHeight: '100vh', color: 'var(--ink)'}}>
      <nav style={{position: 'fixed', top: 0, left: 0, right: 0, padding: '1rem 2rem', borderBottom: '1px solid var(--border)', background: 'var(--paper)', zIndex: 100, display: 'flex', justifyContent: 'space-between', alignItems: 'center', boxShadow: '0 4px 20px rgba(0,0,0,0.03)'}}>
        <Link to="/" onClick={() => { const w = document.querySelector('.landing-page-wrapper'); if(w) w.scrollTo(0,0); }} style={{fontFamily: 'var(--sans)', fontWeight: 800, fontSize: '1.4rem', color: 'var(--ink)', textDecoration: 'none', transition: 'transform 0.2s'}} onMouseOver={e => e.currentTarget.style.transform = 'scale(1.05)'} onMouseOut={e => e.currentTarget.style.transform = 'scale(1)'}>TradeOS<span style={{color: 'var(--accent)'}}>.</span></Link>
        <Link to="/" onClick={() => { const w = document.querySelector('.landing-page-wrapper'); if(w) w.scrollTo(0,0); }} style={{fontFamily: 'var(--mono)', fontSize: '0.8rem', color: 'var(--ink-2)', textDecoration: 'none', padding: '0.5rem 1rem', borderRadius: '20px', border: '1px solid var(--border)', transition: 'all 0.2s'}} onMouseOver={e => {e.currentTarget.style.background='var(--paper-2)'; e.currentTarget.style.color='var(--ink)'}} onMouseOut={e => {e.currentTarget.style.background='transparent'; e.currentTarget.style.color='var(--ink-2)'}}>← Back to Home</Link>
      </nav>
      <div className="section-inner" style={{maxWidth: '800px', margin: '0 auto', paddingBottom: '4rem'}}>
        <style dangerouslySetInnerHTML={{__html: `
.sr-only{position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0,0,0,0);}
* { box-sizing: border-box; }
@keyframes slideUpFade {
  from { opacity: 0; transform: translateY(30px); }
  to { opacity: 1; transform: translateY(0); }
}
.animate-enter { animation: slideUpFade 0.8s cubic-bezier(0.16, 1, 0.3, 1) forwards; opacity: 0; }
.delay-1 { animation-delay: 0.1s; }
.delay-2 { animation-delay: 0.2s; }
.delay-3 { animation-delay: 0.3s; }

.page-title { font-size: 3rem; font-weight: 900; margin-bottom: 1rem; text-align: center; background: linear-gradient(135deg, var(--ink) 0%, var(--accent) 100%); -webkit-background-clip: text; -webkit-text-fill-color: transparent; letter-spacing: -0.02em; }
.page-subtitle { text-align: center; color: var(--ink-2); font-size: 1.2rem; margin-bottom: 3.5rem; text-transform: uppercase; letter-spacing: 0.15em; font-weight: 500; }

.step-wrap { border: 1px solid var(--border); border-radius: 12px; overflow: hidden; margin-bottom: 16px; transition: transform 0.2s, box-shadow 0.2s; background: var(--paper); }
.step-wrap:hover { transform: translateY(-2px); box-shadow: 0 8px 24px rgba(0,0,0,0.04); border-color: rgba(92,202,138,0.3); }
.step-header { display: flex; align-items: center; gap: 16px; padding: 16px 20px; background: var(--paper-2); cursor: pointer; user-select: none; transition: background 0.2s; }
.step-header:hover { background: var(--paper-3); }
.step-num { font-size: 12px; font-weight: 600; letter-spacing: .15em; color: var(--accent); min-width: 24px; }
.step-title { font-size: 16px; font-weight: 600; color: var(--ink); flex: 1; }
.step-badge { font-size: 12px; padding: 4px 12px; border-radius: 20px; white-space: nowrap; font-weight: 500; }
.badge-does { background: rgba(92,202,138,0.15); color: var(--green-2); }
.badge-assists { background: rgba(86,170,255,0.15); color: #56aaff; }
.badge-no { background: var(--paper-3); color: var(--ink-2); border: 1px solid var(--border); }
.step-body { padding: 0 20px; max-height: 0; overflow: hidden; transition: max-height .4s cubic-bezier(0.16, 1, 0.3, 1), padding .4s ease; }
.step-body.open { max-height: 600px; padding: 20px; }
.row-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; margin-top: 12px; }
.mini-card { padding: 16px; border-radius: 8px; transition: transform 0.2s; }
.mini-card:hover { transform: scale(1.02); }
.mini-card.does { background: rgba(92,202,138,0.05); border: 1px solid rgba(92,202,138,0.1); }
.mini-card.does-not { background: var(--paper-2); border: 1px solid var(--border); }
.mini-card-lbl { font-size: 12px; font-weight: 600; text-transform: uppercase; letter-spacing: .1em; margin-bottom: 8px; }
.mini-card.does .mini-card-lbl { color: var(--green-2); }
.mini-card.does-not .mini-card-lbl { color: var(--ink-2); }
.mini-card p { font-size: 13px; line-height: 1.6; margin: 0; color: var(--ink-2); }
.saving-pill { display: inline-flex; align-items: center; gap: 6px; font-size: 12px; font-weight: 500; padding: 4px 12px; border-radius: 20px; background: rgba(219,165,24,0.15); color: #dba518; margin-top: 12px; box-shadow: 0 2px 8px rgba(219,165,24,0.1); }
.chev { font-size: 14px; color: var(--ink-3); transition: transform .3s; }
.chev.open { transform: rotate(180deg); color: var(--accent); }
.legend { display: flex; gap: 20px; margin-bottom: 24px; flex-wrap: wrap; justify-content: center; }
.leg-item { display: flex; align-items: center; gap: 8px; font-size: 13px; color: var(--ink-2); font-weight: 500; }
.leg-dot { width: 10px; height: 10px; border-radius: 50%; box-shadow: 0 0 8px currentColor; }
.leg-dot.green { background: var(--green-2); color: var(--green-2); }
.leg-dot.blue { background: #56aaff; color: #56aaff; }
.leg-dot.gray { background: var(--border); color: transparent; box-shadow: none; }
.summary-bar { display: grid; grid-template-columns: repeat(3,1fr); gap: 16px; margin-bottom: 32px; }
.sum-card { background: linear-gradient(145deg, var(--paper-2), var(--paper)); border: 1px solid var(--border); border-radius: 12px; padding: 20px 16px; text-align: center; transition: transform 0.2s, box-shadow 0.2s; box-shadow: 0 4px 12px rgba(0,0,0,0.02); }
.sum-card:hover { transform: translateY(-4px); box-shadow: 0 12px 24px rgba(0,0,0,0.06); border-color: var(--accent); }
.sum-val { font-size: 28px; font-weight: 700; color: var(--ink); margin-bottom: 4px; background: linear-gradient(135deg, var(--ink) 0%, var(--accent) 100%); -webkit-background-clip: text; -webkit-text-fill-color: transparent; }
.sum-lbl { font-size: 13px; font-weight: 500; color: var(--ink-3); }
@media (max-width: 768px) {
  .page-title { font-size: 2rem; }
  .page-subtitle { font-size: 1rem; margin-bottom: 2rem; }
  .summary-bar { grid-template-columns: 1fr; gap: 12px; }
  .row-grid { grid-template-columns: 1fr; }
  .step-header { flex-wrap: wrap; }
  .step-badge { margin-left: auto; }
}
` }} />
        <div className="animate-enter">
          <h1 className="page-title">How TradeOS Works</h1>
          <p className="page-subtitle">An honest breakdown of where the platform helps, assists, or does not apply at each step of an India–GCC export shipment.</p>
        </div>
        <div style={{padding: '0.5rem 0 1rem'}}>
          <div className="summary-bar animate-enter delay-1">
            <div className="sum-card"><div className="sum-val" style={{color: 'var(--color-text-success)'}}>3</div><div className="sum-lbl">Steps TradeOS fully handles</div></div>
            <div className="sum-card"><div className="sum-val" style={{color: 'var(--color-text-info)'}}>2</div><div className="sum-lbl">Steps we make faster</div></div>
            <div className="sum-card"><div className="sum-val" style={{color: 'var(--color-text-tertiary)'}}>2</div><div className="sum-lbl">Steps outside our scope</div></div>
          </div>
          <div className="legend">
            <div className="leg-item"><div className="leg-dot green" />TradeOS handles this</div>
            <div className="leg-item"><div className="leg-dot blue" />TradeOS assists / speeds up</div>
            <div className="leg-item"><div className="leg-dot gray" />Not our scope (human/physical)</div>
          </div>
          <div className="steps-container">
            {steps.map((s, i) => {
              const isOpen = openStep === i;
              const badgeClass = s.badge === 'does' ? 'badge-does' : s.badge === 'assists' ? 'badge-assists' : 'badge-no';
              return (
                <div key={i} className="step-wrap animate-enter" style={{ animationDelay: `${0.2 + i * 0.1}s` }}>
                  <div className="step-header" onClick={() => setOpenStep(isOpen ? null : i)}>
                    <span className="step-num">{s.num}</span>
                    <span className="step-title">{s.title}</span>
                    <span className={`step-badge ${badgeClass}`}>{s.badgeText}</span>
                    <span className={`chev ${isOpen ? 'open' : ''}`}>▾</span>
                  </div>
                  <div className={`step-body ${isOpen ? 'open' : ''}`}>
                    <p style={{fontSize: '13px', color: 'var(--ink-2)', margin: '0 0 10px', lineHeight: 1.6}}>{s.summary}</p>
                    <div className="row-grid">
                      <div className="mini-card does">
                        <div className="mini-card-lbl">What TradeOS does</div>
                        <p>{s.does}</p>
                      </div>
                      <div className="mini-card does-not">
                        <div className="mini-card-lbl">What it does not do</div>
                        <p>{s.doesNot}</p>
                      </div>
                    </div>
                    <div className="saving-pill">
                      <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" style={{marginRight: '4px'}}><line x1="12" y1="5" x2="12" y2="19"></line><polyline points="19 12 12 19 5 12"></polyline></svg>
                      {s.saving}
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>
    </div>
  );
}
