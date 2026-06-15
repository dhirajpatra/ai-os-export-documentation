export async function apiFetch(url, options = {}) {
  let token = localStorage.getItem('access_token');
  
  // Local development fallback as requested
  if (!token) {
    token = 'dev-token';
    localStorage.setItem('access_token', token);
  }
  
  const headers = {
    ...options.headers,
    'Authorization': `Bearer ${token}`,
  };
  
  const response = await fetch(url, { ...options, headers });
  
  if (response.status === 401) {
    localStorage.removeItem('access_token');
    window.location.href = '/login';
    throw new Error("Unauthorized");
  }
  
  return response;
}
