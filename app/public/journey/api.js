// The adapter owns authentication and transport; views receive server projections.
const key = 'tao-journey-token';
let token = sessionStorage.getItem(key) || localStorage.getItem('tao-token');
if (token) sessionStorage.setItem(key, token);
export class ApiError extends Error {
  constructor(message,status,code,staleSession=false){super(message);this.status=status;this.code=code;this.staleSession=staleSession;}
}
export const api = {
  get authenticated() { return Boolean(token); },
  logout() { token = null; sessionStorage.removeItem(key); localStorage.removeItem('tao-token'); },
  async request(path, method = 'GET', body) {
    const authenticating=path==='/auth/login'||path==='/auth/register';
    const requestToken=authenticating?null:token;
    let response;
    try {
      response = await fetch(path, {method, headers: {
        ...(body ? {'Content-Type': 'application/json'} : {}),
        ...(requestToken ? {Authorization: `Bearer ${requestToken}`} : {})
      }, ...(body ? {body: JSON.stringify(body)} : {})});
    } catch { throw new Error('Unable to connect. Your saved journey remains on the server. Please try again.'); }
    let result;
    try {result=await response.json();}catch{throw new Error('The server returned an unexpected response. Please try again.');}
    if (!response.ok) {
      const staleSession=response.status===401&&!authenticating&&requestToken!==token;
      // A delayed failure from an earlier session must never revoke a new login.
      if (response.status===401&&!authenticating&&!staleSession) api.logout();
      const message=response.status===401
        ? authenticating?'User ID or password is incorrect. Check your details and try again.':'Your session is no longer valid. Please log in again.'
        : result.error || 'The request could not be completed. Please try again.';
      throw new ApiError(message,response.status,result.code,staleSession);
    }
    return result;
  },
  async authenticate(mode, username, password) {
    const result = await api.request(`/auth/${mode}`, 'POST', {authUsername: username.trim(), authPassword: password});
    token = result.authToken;
    sessionStorage.setItem(key, token);
    localStorage.removeItem('tao-token');
  },
  game: () => api.request('/game'),
  states: () => api.request('/states'),
  saveQuestion: (question, text) => api.request(question ? `/game/question/${question.questionId}` : '/game/question', question ? 'PUT' : 'POST', {requestedQuestionText: text})
};
