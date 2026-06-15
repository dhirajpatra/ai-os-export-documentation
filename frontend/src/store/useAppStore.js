import { create } from 'zustand';

export const useAppStore = create((set) => ({
  language: 'EN',
  setLanguage: (lang) => set({ language: lang }),
  
  // Auth State
  isAuthenticated: false,
  user: null,
  loginTimestamp: null,
  
  login: (user, token) => {
    localStorage.setItem('access_token', token);
    const now = Date.now();
    localStorage.setItem('login_timestamp', now.toString());
    set({ isAuthenticated: true, user, loginTimestamp: now });
  },
  
  logout: () => {
    localStorage.removeItem('access_token');
    localStorage.removeItem('login_timestamp');
    set({ isAuthenticated: false, user: null, loginTimestamp: null });
  },
  
  // Checking existing token on load
  initAuth: () => {
    const token = localStorage.getItem('access_token');
    const timestampStr = localStorage.getItem('login_timestamp');
    if (token && timestampStr) {
      const loginTime = parseInt(timestampStr, 10);
      const thirtyMinutes = 30 * 60 * 1000;
      if (Date.now() - loginTime < thirtyMinutes) {
        // Technically we should also store user info in localStorage if we want it to persist across reloads,
        // or fetch it from an endpoint. For now, we'll mark as authenticated.
        const storedUser = localStorage.getItem('user_info');
        set({ 
          isAuthenticated: true, 
          loginTimestamp: loginTime,
          user: storedUser ? JSON.parse(storedUser) : null 
        });
      } else {
        // expired
        localStorage.removeItem('access_token');
        localStorage.removeItem('login_timestamp');
        localStorage.removeItem('user_info');
      }
    }
  },
  
  activeShipments: 142,
  documentsGenerated: 1284,
  complianceSuccess: 98.7,
  aiThroughput: 91,

  // We can add actions to update these later
  incrementShipment: () => set((state) => ({ activeShipments: state.activeShipments + 1 })),
}));
