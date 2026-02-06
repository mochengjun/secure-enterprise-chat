// API Configuration
const API_BASE_URL = 'http://localhost:8081/api/v1';

// Token Management
const TokenManager = {
    getToken() {
        return localStorage.getItem('access_token');
    },
    
    setToken(token) {
        localStorage.setItem('access_token', token);
    },
    
    getRefreshToken() {
        return localStorage.getItem('refresh_token');
    },
    
    setRefreshToken(token) {
        localStorage.setItem('refresh_token', token);
    },
    
    clearTokens() {
        localStorage.removeItem('access_token');
        localStorage.removeItem('refresh_token');
    },
    
    isLoggedIn() {
        return !!this.getToken();
    }
};

// API Client
const api = {
    async request(endpoint, options = {}) {
        const url = `${API_BASE_URL}${endpoint}`;
        const headers = {
            'Content-Type': 'application/json',
            ...options.headers
        };
        
        const token = TokenManager.getToken();
        if (token) {
            headers['Authorization'] = `Bearer ${token}`;
        }
        
        try {
            const response = await fetch(url, {
                ...options,
                headers
            });
            
            const data = await response.json();
            
            if (!response.ok) {
                throw new Error(data.error || 'Request failed');
            }
            
            return data;
        } catch (error) {
            console.error('API Error:', error);
            throw error;
        }
    },
    
    get(endpoint) {
        return this.request(endpoint, { method: 'GET' });
    },
    
    post(endpoint, data) {
        return this.request(endpoint, {
            method: 'POST',
            body: JSON.stringify(data)
        });
    },
    
    put(endpoint, data) {
        return this.request(endpoint, {
            method: 'PUT',
            body: JSON.stringify(data)
        });
    },
    
    delete(endpoint) {
        return this.request(endpoint, { method: 'DELETE' });
    }
};

// Auth API
const AuthAPI = {
    async login(username, password) {
        const data = await api.post('/auth/login', { username, password });
        TokenManager.setToken(data.access_token);
        TokenManager.setRefreshToken(data.refresh_token);
        return data;
    },
    
    async logout() {
        try {
            await api.post('/auth/logout', {
                refresh_token: TokenManager.getRefreshToken()
            });
        } catch (e) {
            // Ignore logout errors
        }
        TokenManager.clearTokens();
    },
    
    async getCurrentUser() {
        return api.get('/auth/me');
    }
};

// Admin API
const AdminAPI = {
    // Status
    async checkStatus() {
        return api.get('/admin/status');
    },
    
    // Stats
    async getStats() {
        return api.get('/admin/stats');
    },
    
    async getUserStats() {
        return api.get('/admin/stats/users');
    },
    
    async getRoomStats() {
        return api.get('/admin/stats/rooms');
    },
    
    async getMessageStats() {
        return api.get('/admin/stats/messages');
    },
    
    // Users
    async getUsers(page = 1, pageSize = 10, search = '', activeOnly = false) {
        const params = new URLSearchParams({
            page,
            page_size: pageSize,
            ...(search && { search }),
            ...(activeOnly && { active_only: 'true' })
        });
        return api.get(`/admin/users?${params}`);
    },
    
    async getUser(userId) {
        return api.get(`/admin/users/${encodeURIComponent(userId)}`);
    },
    
    async updateUserStatus(userId, isActive) {
        return api.put(`/admin/users/${encodeURIComponent(userId)}/status`, { is_active: isActive });
    },
    
    async resetUserPassword(userId, newPassword) {
        return api.post(`/admin/users/${encodeURIComponent(userId)}/reset-password`, { new_password: newPassword });
    },
    
    async deleteUser(userId) {
        return api.delete(`/admin/users/${encodeURIComponent(userId)}`);
    },
    
    // Admins
    async getAdmins() {
        return api.get('/admin/admins');
    },
    
    async createAdmin(userId, role) {
        return api.post('/admin/admins', { user_id: userId, role });
    },
    
    async updateAdminRole(userId, role) {
        return api.put(`/admin/admins/${encodeURIComponent(userId)}`, { role });
    },
    
    async deleteAdmin(userId) {
        return api.delete(`/admin/admins/${encodeURIComponent(userId)}`);
    },
    
    // Rooms
    async getRooms(page = 1, pageSize = 10, search = '', type = '') {
        const params = new URLSearchParams({
            page,
            page_size: pageSize,
            ...(search && { search }),
            ...(type && { type })
        });
        return api.get(`/admin/rooms?${params}`);
    },
    
    async getRoom(roomId) {
        return api.get(`/admin/rooms/${encodeURIComponent(roomId)}`);
    },
    
    async getRoomMembers(roomId) {
        return api.get(`/admin/rooms/${encodeURIComponent(roomId)}/members`);
    },
    
    async deleteRoom(roomId) {
        return api.delete(`/admin/rooms/${encodeURIComponent(roomId)}`);
    },
    
    // Audit Logs
    async getAuditLogs(page = 1, pageSize = 20, action = '', actorId = '', startTime = '', endTime = '') {
        const params = new URLSearchParams({
            page,
            page_size: pageSize,
            ...(action && { action }),
            ...(actorId && { actor_id: actorId }),
            ...(startTime && { start_time: startTime }),
            ...(endTime && { end_time: endTime })
        });
        return api.get(`/admin/audit-logs?${params}`);
    },
    
    // Settings
    async getSettings() {
        return api.get('/admin/settings');
    },
    
    async getSetting(key) {
        return api.get(`/admin/settings/${encodeURIComponent(key)}`);
    },
    
    async updateSetting(key, value, description = '') {
        return api.put(`/admin/settings/${encodeURIComponent(key)}`, { value, description });
    }
};

// Export for use
window.TokenManager = TokenManager;
window.AuthAPI = AuthAPI;
window.AdminAPI = AdminAPI;
