import React, { useState, useEffect } from 'react';
import { X } from 'lucide-react';

export default function WhatsAppWidget() {
  const [isOpen, setIsOpen] = useState(false);

  useEffect(() => {
    let timer;
    if (isOpen) {
      timer = setTimeout(() => {
        setIsOpen(false);
      }, 10000); // Auto close after 10 seconds
    }
    return () => clearTimeout(timer);
  }, [isOpen]);

  const handleWhatsAppClick = () => {
    // Base64 for "917893273022" to prevent scrapers from extracting the number
    const num = atob("OTE3ODkzMjczMDIy");
    window.open(`https://wa.me/${num}?text=Hi%2C%20I'm%20interested%20in%20TradeOS!`, '_blank');
  };

  return (
    <div style={{ position: 'fixed', bottom: '2rem', right: '2rem', zIndex: 9999, display: 'flex', flexDirection: 'column', alignItems: 'flex-end' }}>
      
      {/* Chat Box */}
      {isOpen && (
        <div 
          className="animate-fade-in"
          style={{
            width: '320px',
            background: '#fff',
            borderRadius: '1rem',
            boxShadow: '0 10px 25px rgba(0,0,0,0.5)',
            marginBottom: '1rem',
            overflow: 'hidden',
            display: 'flex',
            flexDirection: 'column'
          }}
        >
          {/* Header */}
          <div style={{ background: '#095e54', padding: '1rem', display: 'flex', alignItems: 'center', position: 'relative' }}>
            <button 
              onClick={() => setIsOpen(false)}
              style={{ position: 'absolute', top: '0.75rem', right: '0.75rem', background: 'transparent', border: 'none', color: '#fff', cursor: 'pointer', opacity: 0.8 }}
            >
              <X size={18} />
            </button>
            <div style={{ position: 'relative', marginRight: '1rem' }}>
              <img src="/logo.jpeg" alt="TradeOS" style={{ width: '48px', height: '48px', borderRadius: '50%', border: '2px solid rgba(255,255,255,0.2)' }} />
              <div style={{ position: 'absolute', bottom: '0', right: '0', width: '12px', height: '12px', background: '#25d366', borderRadius: '50%', border: '2px solid #095e54' }}></div>
            </div>
            <div>
              <h4 style={{ color: '#fff', margin: 0, fontSize: '1.1rem', fontWeight: '600' }}>TradeOS Support</h4>
              <p style={{ color: 'rgba(255,255,255,0.8)', margin: '0.25rem 0 0 0', fontSize: '0.8rem' }}>Typically replies within minutes</p>
            </div>
          </div>

          {/* Chat Body */}
          <div style={{ background: '#e5ddd5', padding: '1.5rem 1rem', minHeight: '150px' }}>
            <div style={{ 
              background: '#dcf8c6', 
              padding: '0.75rem 1rem', 
              borderRadius: '0 0.75rem 0.75rem 0.75rem',
              color: '#303030',
              fontSize: '0.9rem',
              maxWidth: '85%',
              boxShadow: '0 1px 2px rgba(0,0,0,0.1)',
              position: 'relative'
            }}>
              Hi there! 👋<br/><br/>Any questions related to TradeOS? We're here to help!
              <div style={{ position: 'absolute', top: 0, left: '-8px', width: 0, height: 0, borderTop: '0px solid transparent', borderRight: '10px solid #dcf8c6', borderBottom: '10px solid transparent' }}></div>
            </div>
          </div>

          {/* Footer */}
          <div style={{ padding: '1rem', background: '#fff', textAlign: 'center' }}>
            <button 
              onClick={handleWhatsAppClick}
              style={{
                width: '100%',
                background: '#25d366',
                color: '#fff',
                border: 'none',
                padding: '0.75rem',
                borderRadius: '2rem',
                fontSize: '1rem',
                fontWeight: 'bold',
                cursor: 'pointer',
                display: 'flex',
                justifyContent: 'center',
                alignItems: 'center',
                gap: '0.5rem',
                boxShadow: '0 4px 10px rgba(37, 211, 102, 0.3)'
              }}
            >
              <svg width="20" height="20" viewBox="0 0 24 24" fill="white" xmlns="http://www.w3.org/2000/svg">
                <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.888-.788-1.487-1.761-1.66-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51a12.8 12.8 0 0 0-.57-.01c-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 0 1-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 0 1-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 0 1 2.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0 0 12.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 0 0 5.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 0 0-3.48-8.413Z"/>
              </svg>
              WhatsApp Us
            </button>
            <p style={{ margin: '0.75rem 0 0 0', fontSize: '0.75rem', color: '#666' }}>Online | Privacy policy</p>
          </div>
        </div>
      )}

      {/* Floating Button */}
      <button 
        className="whatsapp-float-btn"
        onClick={() => setIsOpen(!isOpen)}
        title="Contact us on WhatsApp"
      >
        {isOpen ? (
          <X size={28} color="white" />
        ) : (
          <svg width="32" height="32" viewBox="0 0 24 24" fill="white" xmlns="http://www.w3.org/2000/svg">
            <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.888-.788-1.487-1.761-1.66-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51a12.8 12.8 0 0 0-.57-.01c-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 0 1-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 0 1-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 0 1 2.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0 0 12.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 0 0 5.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 0 0-3.48-8.413Z"/>
          </svg>
        )}
      </button>
    </div>
  );
}
