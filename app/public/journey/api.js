// The adapter owns authentication and transport; views receive server projections.
const key = 'tao-journey-token';
let token = sessionStorage.getItem(key) || localStorage.getItem('tao-token');
if (token) sessionStorage.setItem(key, token);
export const api = {
  get authenticated() { return Boolean(token); },
  logout() { token = null; sessionStorage.removeItem(key); localStorage.removeItem('tao-token'); },
  async request(path, method = 'GET', body) {
    let response;
    try {
      response = await fetch(path, {method, headers: {
        ...(body ? {'Content-Type': 'application/json'} : {}),
        ...(token ? {Authorization: `Bearer ${token}`} : {})
      }, ...(body ? {body: JSON.stringify(body)} : {})});
    } catch { throw new Error('Unable to connect. Your saved journey remains on the server. Please try again.'); }
    const result = await response.json();
    if (!response.ok) {
      if (response.status === 401) api.logout();
      throw new Error(result.error || 'The request could not be completed. Please try again.');
    }
    return result;
  },
  async authenticate(mode, username, password) {
    const result = await api.request(`/auth/${mode}`, 'POST', {authUsername: username.trim(), authPassword: password});
    token = result.authToken;
    sessionStorage.setItem(key, token);
  },
  game: () => api.request('/game'),
  states: () => api.request('/states'),
  saveQuestion: (question, text) => api.request(question ? `/game/question/${question.questionId}` : '/game/question', question ? 'PUT' : 'POST', {requestedQuestionText: text})
};
