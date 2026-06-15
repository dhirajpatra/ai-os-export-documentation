import React from 'react';
import { Link } from 'react-router-dom';

export default function CostBreakdownPage() {
  return (
    <div className="landing-page-wrapper" style={{paddingTop: '6rem', backgroundColor: 'var(--paper)', minHeight: '100vh', color: 'var(--ink)'}}>
      <nav style={{position: 'fixed', top: 0, left: 0, right: 0, padding: '1rem 2rem', borderBottom: '1px solid var(--border)', background: 'var(--paper)', zIndex: 100, display: 'flex', justifyContent: 'space-between', alignItems: 'center', boxShadow: '0 4px 20px rgba(0,0,0,0.03)'}}>
        <Link to="/" onClick={() => { const w = document.querySelector('.landing-page-wrapper'); if(w) w.scrollTo(0,0); }} style={{fontFamily: 'var(--sans)', fontWeight: 800, fontSize: '1.4rem', color: 'var(--ink)', textDecoration: 'none', transition: 'transform 0.2s'}} onMouseOver={e => e.currentTarget.style.transform = 'scale(1.05)'} onMouseOut={e => e.currentTarget.style.transform = 'scale(1)'}>TradeOS<span style={{color: 'var(--accent)'}}>.</span></Link>
        <Link to="/" onClick={() => { const w = document.querySelector('.landing-page-wrapper'); if(w) w.scrollTo(0,0); }} style={{fontFamily: 'var(--mono)', fontSize: '0.8rem', color: 'var(--ink-2)', textDecoration: 'none', padding: '0.5rem 1rem', borderRadius: '20px', border: '1px solid var(--border)', transition: 'all 0.2s'}} onMouseOver={e => {e.currentTarget.style.background='var(--paper-2)'; e.currentTarget.style.color='var(--ink)'}} onMouseOut={e => {e.currentTarget.style.background='transparent'; e.currentTarget.style.color='var(--ink-2)'}}>← Back to Home</Link>
      </nav>
      <div className="section-inner" style={{maxWidth: '800px', margin: '0 auto', paddingBottom: '4rem'}}>
        <style dangerouslySetInnerHTML={{__html: `
  .sr-only{position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0,0,0,0);}
  
  @keyframes slideUpFade {
    from { opacity: 0; transform: translateY(30px); }
    to { opacity: 1; transform: translateY(0); }
  }
  @keyframes pulseGlow {
    0% { box-shadow: 0 0 0 0 rgba(92,202,138,0.4); }
    70% { box-shadow: 0 0 0 10px rgba(92,202,138,0); }
    100% { box-shadow: 0 0 0 0 rgba(92,202,138,0); }
  }
  .animate-enter { animation: slideUpFade 0.8s cubic-bezier(0.16, 1, 0.3, 1) forwards; opacity: 0; }
  .delay-1 { animation-delay: 0.1s; }
  .delay-2 { animation-delay: 0.2s; }
  .delay-3 { animation-delay: 0.3s; }
  .delay-4 { animation-delay: 0.4s; }
  .delay-5 { animation-delay: 0.5s; }
  .delay-6 { animation-delay: 0.6s; }
  .delay-7 { animation-delay: 0.7s; }
  .delay-8 { animation-delay: 0.8s; }
  
  .page-title { font-size: 3rem; font-weight: 900; margin-bottom: 1rem; text-align: center; background: linear-gradient(135deg, var(--ink) 0%, var(--accent) 100%); -webkit-background-clip: text; -webkit-text-fill-color: transparent; letter-spacing: -0.02em; }
  .page-subtitle { text-align: center; color: var(--ink-2); font-size: 1.2rem; margin-bottom: 3.5rem; text-transform: uppercase; letter-spacing: 0.15em; font-weight: 500; }

  .section-lbl{font-size:12px;font-weight:600;letter-spacing:.15em;text-transform:uppercase;color:var(--accent);margin:0 0 16px;}
  .cost-row{display:flex;align-items:center;gap:16px;padding:16px 20px;border-bottom:1px solid var(--border); transition: all 0.3s cubic-bezier(0.16, 1, 0.3, 1); border-radius: 12px; margin-bottom: 8px;}
  .cost-row:hover{background: var(--paper-2); transform: scale(1.02) translateX(10px); box-shadow: 0 4px 15px rgba(0,0,0,0.03); border-color: transparent;}
  .cost-row:last-child{border-bottom:none;}
  .cost-label{flex:1;font-size:14px;font-weight: 600;color:var(--ink);}
  .cost-sub{font-size:12px;color:var(--ink-3);margin-top:4px; font-weight: 400;}
  .cost-bar-wrap{width:200px;height:10px;background:var(--paper-3);border-radius:10px;overflow:hidden; box-shadow: inset 0 1px 3px rgba(0,0,0,0.1);}
  .cost-bar{height:100%;border-radius:10px; transition: width 1.5s cubic-bezier(0.16, 1, 0.3, 1); background-image: linear-gradient(90deg, rgba(255,255,255,0.1) 0%, transparent 100%);}
  .cost-amt{width:120px;text-align:right;font-size:14px;font-weight:600;color:var(--ink);}
  .cost-pct{width:40px;text-align:right;font-size:12px;font-weight:600;color:var(--ink-3);}
  .total-row{display:flex;justify-content:space-between;align-items:center;padding:24px 30px;background:linear-gradient(145deg, var(--paper-2), var(--paper));border: 1px solid var(--border);border-radius:16px;margin-top:30px;box-shadow: 0 10px 30px rgba(0,0,0,0.05); transition: transform 0.3s;}
  .total-row:hover{transform: translateY(-5px); box-shadow: 0 15px 40px rgba(0,0,0,0.08);}
  .total-lbl{font-size:16px;font-weight: 600; color:var(--ink-2); text-transform: uppercase; letter-spacing: 0.1em;}
  .total-amt{font-size:32px;font-weight:800;color:var(--ink); background: linear-gradient(135deg, var(--ink) 0%, var(--accent) 100%); -webkit-background-clip: text; -webkit-text-fill-color: transparent;}
  .sweetspot-card{border:2px solid var(--green-2);border-radius:12px;padding:20px;background:var(--paper);margin-bottom:12px; transition: transform 0.2s, box-shadow 0.2s;}
  .sweetspot-card:hover{transform: translateY(-2px); box-shadow: 0 8px 24px rgba(92,202,138,0.15);}
  .sweetspot-card.dim{border-color:var(--border); opacity: 0.9;}
  .sweetspot-card.dim:hover{box-shadow: 0 8px 24px rgba(0,0,0,0.04); opacity: 1;}
  .badge{display:inline-block;font-size:12px;font-weight:600;padding:4px 12px;border-radius:20px;}
  .badge-green{background:rgba(92,202,138,0.15);color:var(--green-2);}
  .badge-amber{background:rgba(219,165,24,0.15);color:#dba518;}
  .badge-gray{background:var(--paper-3);color:var(--ink-2);}
  .card-title{font-size:16px;font-weight:600;margin:12px 0 8px;color:var(--ink);}
  .card-body{font-size:13px;color:var(--ink-2);line-height:1.6;}
  .grid2{display:grid;grid-template-columns:1fr 1fr;gap:16px;}
  .metric-card{background:linear-gradient(145deg, var(--paper-2), var(--paper));border: 1px solid var(--border);border-radius:12px;padding:20px;transition: transform 0.2s;}
  .metric-card:hover{transform: translateY(-2px); border-color: var(--accent);}
  .metric-lbl{font-size:12px;font-weight:600;color:var(--ink-3); text-transform: uppercase; letter-spacing: 0.05em;}
  .metric-val{font-size:24px;font-weight:700;color:var(--ink);margin-top:8px;}
  .metric-sub{font-size:12px;color:var(--ink-2);margin-top:4px;}
  .divider{border:none;border-top:1px solid var(--border);margin:32px 0;}
  @media (max-width: 768px) {
    .page-title { font-size: 2rem; }
    .page-subtitle { font-size: 1rem; margin-bottom: 2rem; }
    .cost-row { flex-wrap: wrap; align-items: flex-start; }
    .cost-label { width: 100%; margin-bottom: 8px; }
    .cost-bar-wrap { width: 100%; margin-bottom: 8px; }
    .total-row { flex-direction: column; align-items: flex-start; gap: 12px; padding: 20px; }
    .grid2 { grid-template-columns: 1fr; }
  }
` }} />
        <div className="animate-enter">
          <h1 className="page-title">Cost Breakdown</h1>
          <p className="page-subtitle">What SME exporters currently pay — per shipment cost stack</p>
        </div>
        <div style={{padding: '0.5rem 0 2rem'}}>
          <div className="animate-enter delay-1" style={{background: 'var(--paper)', border: '1px solid var(--border)', borderRadius: '16px', padding: '24px', marginBottom: '24px', boxShadow: '0 8px 30px rgba(0,0,0,0.04)'}}>
            <div className="cost-row animate-enter delay-2">
              <div className="cost-label">CHA / customs agent fees<div className="cost-sub" style={{color: 'var(--ink-3)'}}>Shipping bill, customs clearance, port liaison</div></div>
              <div className="cost-bar-wrap"><div className="cost-bar" style={{width: '22%', background: 'var(--green-2)'}} /></div>
              <div className="cost-amt">₹3,500 – ₹8,000</div>
              <div className="cost-pct">~8%</div>
            </div>
            <div className="cost-row">
              <div className="cost-label">Freight forwarding service fee<div className="cost-sub">Booking, coordination, documentation assist</div></div>
              <div className="cost-bar-wrap"><div className="cost-bar" style={{width: '30%', background: '#0F6E56'}} /></div>
              <div className="cost-amt">₹5,000 – ₹15,000</div>
              <div className="cost-pct">~12%</div>
            </div>
            <div className="cost-row animate-enter delay-3">
              <div className="cost-label">Port / terminal handling (OTHC)<div className="cost-sub">Container stacking, crane ops, CFS handling</div></div>
              <div className="cost-bar-wrap"><div className="cost-bar" style={{width: '38%', background: '#085041'}} /></div>
              <div className="cost-amt">₹8,000 – ₹15,000</div>
              <div className="cost-pct">~16%</div>
            </div>
            <div className="cost-row">
              <div className="cost-label">Documentation prep (in-house labour)<div className="cost-sub">Senior staff time: ~4–8 hrs per shipment × cost</div></div>
              <div className="cost-bar-wrap"><div className="cost-bar" style={{width: '24%', background: '#BA7517'}} /></div>
              <div className="cost-amt">₹3,000 – ₹8,000</div>
              <div className="cost-pct">~9%</div>
            </div>
            <div className="cost-row">
              <div className="cost-label">Document errors &amp; rework<div className="cost-sub">HS code fixes, customs queries, re-filings</div></div>
              <div className="cost-bar-wrap"><div className="cost-bar" style={{width: '20%', background: '#E24B4A'}} /></div>
              <div className="cost-amt">₹2,000 – ₹10,000</div>
              <div className="cost-pct">~7%</div>
            </div>
            <div className="cost-row">
              <div className="cost-label">Demurrage &amp; detention (when errors occur)<div className="cost-sub">₹5k–10k/day; easily ₹50k+ if HS code wrong</div></div>
              <div className="cost-bar-wrap"><div className="cost-bar" style={{width: '50%', background: '#A32D2D'}} /></div>
              <div className="cost-amt">₹0 – ₹50,000+</div>
              <div className="cost-pct">risk</div>
            </div>
            <div className="cost-row">
              <div className="cost-label">Spices Board / APEDA / halal certs<div className="cost-sub">Mandatory for Kerala agri exports to GCC</div></div>
              <div className="cost-bar-wrap"><div className="cost-bar" style={{width: '15%', background: '#534AB7'}} /></div>
              <div className="cost-amt">₹1,500 – ₹5,000</div>
              <div className="cost-pct">~4%</div>
            </div>
          </div>
          <div className="grid2" style={{marginBottom: '20px'}}>
            <div className="metric-card">
              <div className="metric-lbl">Typical total ops cost / shipment</div>
              <div className="metric-val">₹20k – ₹60k</div>
              <div className="metric-sub">Your business plan figure — validated by research</div>
            </div>
            <div className="metric-card">
              <div className="metric-lbl">Port logistics as % of consignment value</div>
              <div className="metric-val">~15%</div>
              <div className="metric-sub">Dun &amp; Bradstreet study, India average</div>
            </div>
            <div className="metric-card">
              <div className="metric-lbl">Avg shipments / month (10–50 staff SME)</div>
              <div className="metric-val">8 – 30</div>
              <div className="metric-sub">Estimated from trade volume patterns</div>
            </div>
            <div className="metric-card">
              <div className="metric-lbl">Annual ops spend on documentation</div>
              <div className="metric-val">₹3L – ₹18L</div>
              <div className="metric-sub">Labour + CHA + error cost combined</div>
            </div>
          </div>
          <hr className="divider" />
          <p className="section-lbl">TradeOS sweet-spot pricing — post-pilot</p>
          <div className="sweetspot-card">
            <span className="badge badge-green">Recommended — best fit</span>
            <div className="card-title">Flat monthly subscription (volume bands) — ₹15k – ₹40k/month</div>
            <div className="card-body">
              Predictable for the customer. Predictable MRR for you. Price anchored to shipment volume bands (e.g. up to 10/month, 11–30/month, 30+/month) so the customer always feels they're getting more than they pay for. At ₹20k/month for 15 shipments, they're paying ~₹1,333/shipment — vs ₹20k–60k in current ops cost. That's a 15–45× ROI argument.
            </div>
          </div>
          <div className="sweetspot-card dim">
            <span className="badge badge-amber">Phase 2 add-on — not primary</span>
            <div className="card-title">Per-shipment overage charge — ₹500 – ₹1,200 per shipment above plan</div>
            <div className="card-body">
              Once on subscription, charge per-shipment only for overages above their plan tier. Never make this the base model — SMEs hate variable billing when cash flows are uneven. Use it to upsell naturally when a client's volume grows.
            </div>
          </div>
          <div className="sweetspot-card dim">
            <span className="badge badge-gray">Avoid for now</span>
            <div className="card-title">Pure per-shipment billing — ₹1,500 – ₹3,000/shipment</div>
            <div className="card-body">
              Sounds fair but creates friction. Clients will hesitate before each shipment and over-optimise usage. It also makes your MRR lumpy and hard to plan. Reserve this only for one-off / non-subscription clients in Phase 3.
            </div>
          </div>
          <hr className="divider" />
          <p className="section-lbl animate-enter delay-2">Pricing architecture recommendation</p>
          <div className="animate-enter delay-2" style={{background: 'var(--paper)', border: '1px solid var(--border)', borderRadius: '12px', overflow: 'hidden', boxShadow: '0 4px 12px rgba(0,0,0,0.02)'}}>
            <div style={{display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', borderBottom: '1px solid var(--border)', background: 'var(--paper-2)'}}>
              <div style={{padding: '12px 16px', fontSize: '12px', fontWeight: 600, color: 'var(--ink-3)', borderRight: '1px solid var(--border)'}}>Tier</div>
              <div style={{padding: '12px 16px', fontSize: '12px', fontWeight: 600, color: 'var(--ink-3)', borderRight: '1px solid var(--border)'}}>Price / month</div>
              <div style={{padding: '12px 16px', fontSize: '12px', fontWeight: 600, color: 'var(--ink-3)'}}>Effective / shipment</div>
            </div>
            <div style={{display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', borderBottom: '1px solid var(--border)', transition: 'background 0.2s'}} onMouseOver={e => e.currentTarget.style.background = 'var(--paper-2)'} onMouseOut={e => e.currentTarget.style.background = 'transparent'}>
              <div style={{padding: '16px', fontSize: '14px', color: 'var(--ink)', borderRight: '1px solid var(--border)'}}>Starter</div>
              <div style={{padding: '16px', fontSize: '14px', color: 'var(--ink)', borderRight: '1px solid var(--border)'}}>₹20k/month (inc. 15 shipments)</div>
              <div style={{padding: '16px', fontSize: '14px', fontWeight: 600, color: 'var(--accent)'}}>₹1,333</div>
            </div>
            <div style={{display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', borderBottom: '1px solid var(--border)', transition: 'all 0.3s', position: 'relative'}} onMouseOver={e => {e.currentTarget.style.background = 'var(--paper-2)'; e.currentTarget.style.paddingLeft = '10px'}} onMouseOut={e => {e.currentTarget.style.background = 'transparent'; e.currentTarget.style.paddingLeft = '0'}}>
              <div style={{padding: '16px', fontSize: '14px', color: 'var(--ink)', borderRight: '1px solid var(--border)'}}>Growth <span className="badge badge-green" style={{marginLeft: '6px', animation: 'pulseGlow 2s infinite'}}>sweet spot</span></div>
              <div style={{padding: '16px', fontSize: '14px', color: 'var(--ink)', borderRight: '1px solid var(--border)'}}>₹25k – ₹40k (11–30/mo)</div>
              <div style={{padding: '16px', fontSize: '14px', fontWeight: 600, color: 'var(--accent)'}}>₹1,000 – ₹1,600</div>
            </div>
            <div style={{display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', transition: 'all 0.3s'}} onMouseOver={e => {e.currentTarget.style.background = 'var(--paper-2)'; e.currentTarget.style.paddingLeft = '10px'}} onMouseOut={e => {e.currentTarget.style.background = 'transparent'; e.currentTarget.style.paddingLeft = '0'}}>
              <div style={{padding: '16px', fontSize: '14px', color: 'var(--ink)', borderRight: '1px solid var(--border)'}}>Pro</div>
              <div style={{padding: '16px', fontSize: '14px', color: 'var(--ink)', borderRight: '1px solid var(--border)'}}>₹45k/month (inc. 45 shipments)</div>
              <div style={{padding: '16px', fontSize: '14px', fontWeight: 600, color: 'var(--accent)'}}>₹1,000</div>
            </div>
          </div>
          <div className="animate-enter delay-3" style={{marginTop: '20px', padding: '16px 20px', background: 'rgba(0, 229, 255, 0.05)', borderRadius: '12px', border: '1px solid rgba(0, 229, 255, 0.2)'}}>
            <span style={{fontSize: '13px', color: 'var(--accent)', lineHeight: '1.6'}}>
              <i className="ti ti-bulb" style={{fontSize: '14px', verticalAlign: '-2px', marginRight: '5px'}} aria-hidden="true" />
              ROI framing for your sales pitch: a client on the Growth plan at ₹30k/month processing 20 shipments pays ₹1,500/shipment via TradeOS — vs ₹20k–60k in current total ops cost per shipment. Even if TradeOS saves just ₹5,000/shipment in staff time + error cost, that is a 3× return on the subscription fee.
            </span>
          </div>
        </div>
      </div>
    </div>
  );
}
