import { API_URL, AUTH_URL } from './lib/config';
import { NeonHttp } from './lib/http';

export const http = new NeonHttp({ authUrl: AUTH_URL, apiUrl: API_URL });
