// App State
const AppState = {
    currentPage: 'overview',
    adminInfo: null,
    users: { data: [], page: 1, pageSize: 10, total: 0 },
    rooms: { data: [], page: 1, pageSize: 10, total: 0 },
    auditLogs: { data: [], page: 1, pageSize: 20, total: 0 }
};

// DOM Elements
const elements = {
    loginPage: document.getElementById('login-page'),
    dashboard: document.getElementById('dashboard'),
    loginForm: document.getElementById('login-form'),
    loginError: document.getElementById('login-error'),
    logoutBtn: document.getElementById('logout-btn'),
    sidebarToggle: document.getElementById('sidebar-toggle'),
    sidebar: document.querySelector('.sidebar'),
    navItems: document.querySelectorAll('.nav-item'),
    pageTitle: document.getElementById('page-title'),
    adminUsername: document.getElementById('admin-username'),
    adminRole: document.getElementById('admin-role'),
    toastContainer: document.getElementById('toast-container'),
    modalOverlay: document.getElementById('modal-overlay'),
    modalTitle: document.getElementById('modal-title'),
    modalBody: document.getElementById('modal-body'),
    modalFooter: document.getElementById('modal-footer')
};

// Initialize App
document.addEventListener('DOMContentLoaded', () => {
    initApp();
});

async function initApp() {
    if (TokenManager.isLoggedIn()) {
        try {
            await loadAdminInfo();
            showDashboard();
            loadCurrentPage();
        } catch (error) {
            TokenManager.clearTokens();
            showLoginPage();
        }
    } else {
        showLoginPage();
    }
    
    bindEvents();
}

// Event Bindings
function bindEvents() {
    // Login form
    elements.loginForm.addEventListener('submit', handleLogin);
    
    // Logout
    elements.logoutBtn.addEventListener('click', handleLogout);
    
    // Sidebar toggle
    elements.sidebarToggle.addEventListener('click', () => {
        elements.sidebar.classList.toggle('open');
    });
    
    // Navigation
    elements.navItems.forEach(item => {
        item.addEventListener('click', (e) => {
            e.preventDefault();
            const page = item.dataset.page;
            navigateTo(page);
        });
    });
    
    // Users page
    document.getElementById('user-search')?.addEventListener('input', debounce(loadUsers, 300));
    document.getElementById('active-only')?.addEventListener('change', loadUsers);
    document.getElementById('refresh-users')?.addEventListener('click', loadUsers);
    
    // Rooms page
    document.getElementById('room-search')?.addEventListener('input', debounce(loadRooms, 300));
    document.getElementById('room-type-filter')?.addEventListener('change', loadRooms);
    document.getElementById('refresh-rooms')?.addEventListener('click', loadRooms);
    
    // Admins page
    document.getElementById('add-admin-btn')?.addEventListener('click', showAddAdminModal);
    
    // Audit page
    document.getElementById('audit-action-filter')?.addEventListener('change', loadAuditLogs);
    document.getElementById('refresh-audit')?.addEventListener('click', loadAuditLogs);
    
    // Settings page
    document.getElementById('add-setting-btn')?.addEventListener('click', showAddSettingModal);
}

// Auth Handlers
async function handleLogin(e) {
    e.preventDefault();
    const username = document.getElementById('username').value;
    const password = document.getElementById('password').value;
    
    try {
        elements.loginError.textContent = '';
        await AuthAPI.login(username, password);
        
        // Check admin status
        const status = await AdminAPI.checkStatus();
        if (!status.is_admin) {
            TokenManager.clearTokens();
            elements.loginError.textContent = '您没有管理员权限';
            return;
        }
        
        await loadAdminInfo();
        showDashboard();
        loadCurrentPage();
        showToast('登录成功', 'success');
    } catch (error) {
        elements.loginError.textContent = error.message || '登录失败，请检查用户名和密码';
    }
}

async function handleLogout() {
    await AuthAPI.logout();
    showLoginPage();
    showToast('已退出登录', 'info');
}

async function loadAdminInfo() {
    const [user, status] = await Promise.all([
        AuthAPI.getCurrentUser(),
        AdminAPI.checkStatus()
    ]);
    
    AppState.adminInfo = { ...user, ...status };
    elements.adminUsername.textContent = user.username;
    elements.adminRole.textContent = getRoleName(status.role);
    elements.adminRole.className = `badge badge-primary role-${status.role}`;
}

// Page Navigation
function showLoginPage() {
    elements.loginPage.classList.remove('hidden');
    elements.dashboard.classList.add('hidden');
    elements.loginForm.reset();
    elements.loginError.textContent = '';
}

function showDashboard() {
    elements.loginPage.classList.add('hidden');
    elements.dashboard.classList.remove('hidden');
}

function navigateTo(page) {
    AppState.currentPage = page;
    
    // Update nav active state
    elements.navItems.forEach(item => {
        item.classList.toggle('active', item.dataset.page === page);
    });
    
    // Update page title
    const titles = {
        overview: '系统概览',
        users: '用户管理',
        rooms: '房间管理',
        admins: '管理员',
        audit: '审计日志',
        settings: '系统设置'
    };
    elements.pageTitle.textContent = titles[page] || page;
    
    // Show page
    document.querySelectorAll('.page').forEach(p => {
        p.classList.toggle('active', p.id === `page-${page}`);
    });
    
    // Load page data
    loadCurrentPage();
    
    // Close sidebar on mobile
    elements.sidebar.classList.remove('open');
}

function loadCurrentPage() {
    switch (AppState.currentPage) {
        case 'overview':
            loadOverview();
            break;
        case 'users':
            loadUsers();
            break;
        case 'rooms':
            loadRooms();
            break;
        case 'admins':
            loadAdmins();
            break;
        case 'audit':
            loadAuditLogs();
            break;
        case 'settings':
            loadSettings();
            break;
    }
}

// Overview Page
async function loadOverview() {
    try {
        const stats = await AdminAPI.getStats();
        
        // Update stats
        document.getElementById('stat-total-users').textContent = stats.users.total_users;
        document.getElementById('stat-active-users').textContent = stats.users.active_users;
        document.getElementById('stat-total-rooms').textContent = stats.rooms.total_rooms;
        document.getElementById('stat-total-messages').textContent = stats.messages.total_messages;
        
        // Today stats
        document.getElementById('stat-new-users-today').textContent = stats.users.new_users_today;
        document.getElementById('stat-new-rooms-today').textContent = stats.rooms.new_rooms_today;
        document.getElementById('stat-messages-today').textContent = stats.messages.messages_today;
        
        // Room type distribution
        const totalRooms = stats.rooms.total_rooms || 1;
        document.getElementById('stat-direct-rooms').textContent = stats.rooms.direct_rooms;
        document.getElementById('stat-group-rooms').textContent = stats.rooms.group_rooms;
        document.getElementById('stat-channel-rooms').textContent = stats.rooms.channel_rooms;
        
        document.getElementById('progress-direct').style.width = `${(stats.rooms.direct_rooms / totalRooms) * 100}%`;
        document.getElementById('progress-group').style.width = `${(stats.rooms.group_rooms / totalRooms) * 100}%`;
        document.getElementById('progress-channel').style.width = `${(stats.rooms.channel_rooms / totalRooms) * 100}%`;
    } catch (error) {
        showToast('加载统计数据失败', 'error');
    }
}

// Users Page
async function loadUsers() {
    const search = document.getElementById('user-search')?.value || '';
    const activeOnly = document.getElementById('active-only')?.checked || false;
    
    try {
        const data = await AdminAPI.getUsers(AppState.users.page, AppState.users.pageSize, search, activeOnly);
        AppState.users = { ...AppState.users, ...data };
        renderUsersTable();
    } catch (error) {
        showToast('加载用户列表失败', 'error');
    }
}

function renderUsersTable() {
    const tbody = document.getElementById('users-table-body');
    const { users, total, page, page_size } = AppState.users;
    
    tbody.innerHTML = users.map(user => `
        <tr>
            <td class="truncate" title="${user.user_id}">${user.user_id}</td>
            <td>${user.username}</td>
            <td>${user.display_name || '-'}</td>
            <td>${user.email || '-'}</td>
            <td>${user.mfa_enabled ? '<i class="fas fa-check text-success"></i>' : '<i class="fas fa-times text-muted"></i>'}</td>
            <td>
                <span class="badge ${user.is_active ? 'badge-success' : 'badge-danger'}">
                    ${user.is_active ? '活跃' : '禁用'}
                </span>
            </td>
            <td>${formatDate(user.created_at)}</td>
            <td class="actions">
                <button class="btn btn-small btn-secondary" onclick="toggleUserStatus('${user.user_id}', ${!user.is_active})">
                    ${user.is_active ? '禁用' : '启用'}
                </button>
                <button class="btn btn-small btn-secondary" onclick="showResetPasswordModal('${user.user_id}')">
                    重置密码
                </button>
            </td>
        </tr>
    `).join('');
    
    renderPagination('users-pagination', total, page, page_size, (p) => {
        AppState.users.page = p;
        loadUsers();
    });
}

async function toggleUserStatus(userId, isActive) {
    try {
        await AdminAPI.updateUserStatus(userId, isActive);
        showToast(`用户已${isActive ? '启用' : '禁用'}`, 'success');
        loadUsers();
    } catch (error) {
        showToast(error.message, 'error');
    }
}

function showResetPasswordModal(userId) {
    elements.modalTitle.textContent = '重置密码';
    elements.modalBody.innerHTML = `
        <div class="form-group">
            <label>用户ID</label>
            <input type="text" value="${userId}" disabled>
        </div>
        <div class="form-group">
            <label>新密码</label>
            <input type="password" id="new-password" placeholder="请输入新密码（至少8位）" minlength="8">
        </div>
    `;
    elements.modalFooter.innerHTML = `
        <button class="btn btn-secondary" onclick="closeModal()">取消</button>
        <button class="btn btn-primary" onclick="resetPassword('${userId}')">确认重置</button>
    `;
    showModal();
}

async function resetPassword(userId) {
    const password = document.getElementById('new-password').value;
    if (password.length < 8) {
        showToast('密码长度至少8位', 'error');
        return;
    }
    
    try {
        await AdminAPI.resetUserPassword(userId, password);
        showToast('密码重置成功', 'success');
        closeModal();
    } catch (error) {
        showToast(error.message, 'error');
    }
}

// Rooms Page
async function loadRooms() {
    const search = document.getElementById('room-search')?.value || '';
    const type = document.getElementById('room-type-filter')?.value || '';
    
    try {
        const data = await AdminAPI.getRooms(AppState.rooms.page, AppState.rooms.pageSize, search, type);
        AppState.rooms = { ...AppState.rooms, ...data };
        renderRoomsTable();
    } catch (error) {
        showToast('加载房间列表失败', 'error');
    }
}

function renderRoomsTable() {
    const tbody = document.getElementById('rooms-table-body');
    const { rooms, total, page, page_size } = AppState.rooms;
    
    const typeNames = { direct: '私聊', group: '群组', channel: '频道' };
    
    tbody.innerHTML = rooms.map(room => `
        <tr>
            <td class="truncate" title="${room.id}">${room.id}</td>
            <td>${room.name || '-'}</td>
            <td><span class="badge badge-secondary">${typeNames[room.type] || room.type}</span></td>
            <td class="truncate" title="${room.creator_id}">${room.creator_id}</td>
            <td>${formatDate(room.created_at)}</td>
            <td class="actions">
                <button class="btn btn-small btn-secondary" onclick="showRoomMembers('${room.id}')">
                    查看成员
                </button>
                <button class="btn btn-small btn-danger" onclick="confirmDeleteRoom('${room.id}', '${room.name || room.id}')">
                    删除
                </button>
            </td>
        </tr>
    `).join('');
    
    renderPagination('rooms-pagination', total, page, page_size, (p) => {
        AppState.rooms.page = p;
        loadRooms();
    });
}

async function showRoomMembers(roomId) {
    try {
        const data = await AdminAPI.getRoomMembers(roomId);
        const members = data.members || [];
        
        elements.modalTitle.textContent = '房间成员';
        elements.modalBody.innerHTML = `
            <table class="data-table">
                <thead>
                    <tr>
                        <th>用户ID</th>
                        <th>角色</th>
                        <th>加入时间</th>
                    </tr>
                </thead>
                <tbody>
                    ${members.map(m => `
                        <tr>
                            <td>${m.user_id}</td>
                            <td><span class="badge badge-secondary">${m.role}</span></td>
                            <td>${formatDate(m.joined_at)}</td>
                        </tr>
                    `).join('')}
                </tbody>
            </table>
        `;
        elements.modalFooter.innerHTML = `
            <button class="btn btn-secondary" onclick="closeModal()">关闭</button>
        `;
        showModal();
    } catch (error) {
        showToast('加载成员列表失败', 'error');
    }
}

function confirmDeleteRoom(roomId, roomName) {
    elements.modalTitle.textContent = '确认删除';
    elements.modalBody.innerHTML = `
        <p>确定要删除房间 "<strong>${roomName}</strong>" 吗？</p>
        <p class="text-danger">此操作将删除该房间的所有消息和成员记录，且不可恢复！</p>
    `;
    elements.modalFooter.innerHTML = `
        <button class="btn btn-secondary" onclick="closeModal()">取消</button>
        <button class="btn btn-danger" onclick="deleteRoom('${roomId}')">确认删除</button>
    `;
    showModal();
}

async function deleteRoom(roomId) {
    try {
        await AdminAPI.deleteRoom(roomId);
        showToast('房间已删除', 'success');
        closeModal();
        loadRooms();
    } catch (error) {
        showToast(error.message, 'error');
    }
}

// Admins Page
async function loadAdmins() {
    try {
        const data = await AdminAPI.getAdmins();
        renderAdminsTable(data.admins || []);
    } catch (error) {
        showToast('加载管理员列表失败', 'error');
    }
}

function renderAdminsTable(admins) {
    const tbody = document.getElementById('admins-table-body');
    
    tbody.innerHTML = admins.map(admin => `
        <tr>
            <td class="truncate" title="${admin.user_id}">${admin.user_id}</td>
            <td>${admin.username}</td>
            <td><span class="badge badge-primary role-${admin.role}">${getRoleName(admin.role)}</span></td>
            <td>${formatDate(admin.created_at)}</td>
            <td>${admin.created_by || '-'}</td>
            <td class="actions">
                <button class="btn btn-small btn-secondary" onclick="showEditAdminModal('${admin.user_id}', '${admin.role}')">
                    编辑角色
                </button>
                <button class="btn btn-small btn-danger" onclick="confirmDeleteAdmin('${admin.user_id}', '${admin.username}')">
                    移除
                </button>
            </td>
        </tr>
    `).join('');
}

function showAddAdminModal() {
    elements.modalTitle.textContent = '添加管理员';
    elements.modalBody.innerHTML = `
        <div class="form-group">
            <label>用户ID</label>
            <input type="text" id="admin-user-id" placeholder="请输入用户ID（如 @username:sec-chat.local）">
        </div>
        <div class="form-group">
            <label>角色</label>
            <select id="admin-role" class="select-input">
                <option value="viewer">查看者 (Viewer)</option>
                <option value="operator">操作员 (Operator)</option>
                <option value="admin">管理员 (Admin)</option>
                <option value="super_admin">超级管理员 (Super Admin)</option>
            </select>
        </div>
    `;
    elements.modalFooter.innerHTML = `
        <button class="btn btn-secondary" onclick="closeModal()">取消</button>
        <button class="btn btn-primary" onclick="addAdmin()">添加</button>
    `;
    showModal();
}

async function addAdmin() {
    const userId = document.getElementById('admin-user-id').value;
    const role = document.getElementById('admin-role').value;
    
    if (!userId) {
        showToast('请输入用户ID', 'error');
        return;
    }
    
    try {
        await AdminAPI.createAdmin(userId, role);
        showToast('管理员添加成功', 'success');
        closeModal();
        loadAdmins();
    } catch (error) {
        showToast(error.message, 'error');
    }
}

function showEditAdminModal(userId, currentRole) {
    elements.modalTitle.textContent = '编辑管理员角色';
    elements.modalBody.innerHTML = `
        <div class="form-group">
            <label>用户ID</label>
            <input type="text" value="${userId}" disabled>
        </div>
        <div class="form-group">
            <label>角色</label>
            <select id="edit-admin-role" class="select-input">
                <option value="viewer" ${currentRole === 'viewer' ? 'selected' : ''}>查看者 (Viewer)</option>
                <option value="operator" ${currentRole === 'operator' ? 'selected' : ''}>操作员 (Operator)</option>
                <option value="admin" ${currentRole === 'admin' ? 'selected' : ''}>管理员 (Admin)</option>
                <option value="super_admin" ${currentRole === 'super_admin' ? 'selected' : ''}>超级管理员 (Super Admin)</option>
            </select>
        </div>
    `;
    elements.modalFooter.innerHTML = `
        <button class="btn btn-secondary" onclick="closeModal()">取消</button>
        <button class="btn btn-primary" onclick="updateAdminRole('${userId}')">保存</button>
    `;
    showModal();
}

async function updateAdminRole(userId) {
    const role = document.getElementById('edit-admin-role').value;
    
    try {
        await AdminAPI.updateAdminRole(userId, role);
        showToast('角色更新成功', 'success');
        closeModal();
        loadAdmins();
    } catch (error) {
        showToast(error.message, 'error');
    }
}

function confirmDeleteAdmin(userId, username) {
    elements.modalTitle.textContent = '确认移除';
    elements.modalBody.innerHTML = `
        <p>确定要移除 "<strong>${username}</strong>" 的管理员权限吗？</p>
    `;
    elements.modalFooter.innerHTML = `
        <button class="btn btn-secondary" onclick="closeModal()">取消</button>
        <button class="btn btn-danger" onclick="deleteAdmin('${userId}')">确认移除</button>
    `;
    showModal();
}

async function deleteAdmin(userId) {
    try {
        await AdminAPI.deleteAdmin(userId);
        showToast('管理员已移除', 'success');
        closeModal();
        loadAdmins();
    } catch (error) {
        showToast(error.message, 'error');
    }
}

// Audit Logs Page
async function loadAuditLogs() {
    const action = document.getElementById('audit-action-filter')?.value || '';
    
    try {
        const data = await AdminAPI.getAuditLogs(AppState.auditLogs.page, AppState.auditLogs.pageSize, action);
        AppState.auditLogs = { ...AppState.auditLogs, ...data };
        renderAuditTable();
    } catch (error) {
        showToast('加载审计日志失败', 'error');
    }
}

function renderAuditTable() {
    const tbody = document.getElementById('audit-table-body');
    const { logs, total, page, page_size } = AppState.auditLogs;
    
    const actionNames = {
        user_create: '用户创建',
        user_update: '用户更新',
        user_delete: '用户删除',
        user_login: '用户登录',
        user_logout: '用户登出',
        room_create: '房间创建',
        room_update: '房间更新',
        room_delete: '房间删除',
        member_add: '成员添加',
        member_remove: '成员移除',
        member_role: '角色变更',
        message_delete: '消息删除',
        setting_update: '设置更新',
        admin_action: '管理操作'
    };
    
    tbody.innerHTML = logs.map(log => `
        <tr>
            <td>${formatDateTime(log.created_at)}</td>
            <td><span class="badge badge-secondary">${actionNames[log.action] || log.action}</span></td>
            <td>${log.actor_name || log.actor_id}</td>
            <td>${log.target_name || log.target_id || '-'}</td>
            <td class="truncate" title="${log.details || ''}">${log.details || '-'}</td>
            <td>${log.ip_address || '-'}</td>
        </tr>
    `).join('');
    
    renderPagination('audit-pagination', total, page, page_size, (p) => {
        AppState.auditLogs.page = p;
        loadAuditLogs();
    });
}

// Settings Page
async function loadSettings() {
    try {
        const data = await AdminAPI.getSettings();
        renderSettings(data.settings || []);
    } catch (error) {
        showToast('加载系统设置失败', 'error');
    }
}

function renderSettings(settings) {
    const container = document.getElementById('settings-list');
    
    if (settings.length === 0) {
        container.innerHTML = '<p class="text-muted">暂无系统设置</p>';
        return;
    }
    
    container.innerHTML = settings.map(setting => `
        <div class="setting-item">
            <div class="setting-info">
                <div class="setting-key">${setting.key}</div>
                <div class="setting-description">${setting.description || '无描述'}</div>
                <div class="setting-value">${setting.value}</div>
            </div>
            <div class="setting-actions">
                <button class="btn btn-small btn-secondary" onclick="showEditSettingModal('${setting.key}', '${setting.value}', '${setting.description || ''}')">
                    编辑
                </button>
            </div>
        </div>
    `).join('');
}

function showAddSettingModal() {
    elements.modalTitle.textContent = '添加设置';
    elements.modalBody.innerHTML = `
        <div class="form-group">
            <label>设置键名</label>
            <input type="text" id="setting-key" placeholder="例如: max_file_size">
        </div>
        <div class="form-group">
            <label>设置值</label>
            <input type="text" id="setting-value" placeholder="设置值">
        </div>
        <div class="form-group">
            <label>描述</label>
            <input type="text" id="setting-description" placeholder="设置说明（可选）">
        </div>
    `;
    elements.modalFooter.innerHTML = `
        <button class="btn btn-secondary" onclick="closeModal()">取消</button>
        <button class="btn btn-primary" onclick="addSetting()">添加</button>
    `;
    showModal();
}

async function addSetting() {
    const key = document.getElementById('setting-key').value;
    const value = document.getElementById('setting-value').value;
    const description = document.getElementById('setting-description').value;
    
    if (!key || !value) {
        showToast('请填写键名和值', 'error');
        return;
    }
    
    try {
        await AdminAPI.updateSetting(key, value, description);
        showToast('设置添加成功', 'success');
        closeModal();
        loadSettings();
    } catch (error) {
        showToast(error.message, 'error');
    }
}

function showEditSettingModal(key, value, description) {
    elements.modalTitle.textContent = '编辑设置';
    elements.modalBody.innerHTML = `
        <div class="form-group">
            <label>设置键名</label>
            <input type="text" value="${key}" disabled>
        </div>
        <div class="form-group">
            <label>设置值</label>
            <input type="text" id="edit-setting-value" value="${value}">
        </div>
        <div class="form-group">
            <label>描述</label>
            <input type="text" id="edit-setting-description" value="${description}">
        </div>
    `;
    elements.modalFooter.innerHTML = `
        <button class="btn btn-secondary" onclick="closeModal()">取消</button>
        <button class="btn btn-primary" onclick="updateSetting('${key}')">保存</button>
    `;
    showModal();
}

async function updateSetting(key) {
    const value = document.getElementById('edit-setting-value').value;
    const description = document.getElementById('edit-setting-description').value;
    
    try {
        await AdminAPI.updateSetting(key, value, description);
        showToast('设置更新成功', 'success');
        closeModal();
        loadSettings();
    } catch (error) {
        showToast(error.message, 'error');
    }
}

// Modal Functions
function showModal() {
    elements.modalOverlay.classList.remove('hidden');
}

function closeModal() {
    elements.modalOverlay.classList.add('hidden');
}

// Close modal on overlay click
elements.modalOverlay.addEventListener('click', (e) => {
    if (e.target === elements.modalOverlay) {
        closeModal();
    }
});

// Toast Function
function showToast(message, type = 'info') {
    const icons = {
        success: 'fa-check-circle',
        error: 'fa-exclamation-circle',
        warning: 'fa-exclamation-triangle',
        info: 'fa-info-circle'
    };
    
    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    toast.innerHTML = `
        <i class="fas ${icons[type]}"></i>
        <span>${message}</span>
    `;
    
    elements.toastContainer.appendChild(toast);
    
    setTimeout(() => {
        toast.style.opacity = '0';
        setTimeout(() => toast.remove(), 300);
    }, 3000);
}

// Pagination Helper
function renderPagination(containerId, total, page, pageSize, onPageChange) {
    const container = document.getElementById(containerId);
    const totalPages = Math.ceil(total / pageSize);
    
    if (totalPages <= 1) {
        container.innerHTML = '';
        return;
    }
    
    let html = '';
    
    // Previous button
    html += `<button ${page === 1 ? 'disabled' : ''} onclick="(${onPageChange})(${page - 1})">
        <i class="fas fa-chevron-left"></i>
    </button>`;
    
    // Page numbers
    const startPage = Math.max(1, page - 2);
    const endPage = Math.min(totalPages, page + 2);
    
    if (startPage > 1) {
        html += `<button onclick="(${onPageChange})(1)">1</button>`;
        if (startPage > 2) html += '<button disabled>...</button>';
    }
    
    for (let i = startPage; i <= endPage; i++) {
        html += `<button class="${i === page ? 'active' : ''}" onclick="(${onPageChange})(${i})">${i}</button>`;
    }
    
    if (endPage < totalPages) {
        if (endPage < totalPages - 1) html += '<button disabled>...</button>';
        html += `<button onclick="(${onPageChange})(${totalPages})">${totalPages}</button>`;
    }
    
    // Next button
    html += `<button ${page === totalPages ? 'disabled' : ''} onclick="(${onPageChange})(${page + 1})">
        <i class="fas fa-chevron-right"></i>
    </button>`;
    
    container.innerHTML = html;
}

// Utility Functions
function formatDate(dateStr) {
    if (!dateStr) return '-';
    const date = new Date(dateStr);
    return date.toLocaleDateString('zh-CN');
}

function formatDateTime(dateStr) {
    if (!dateStr) return '-';
    const date = new Date(dateStr);
    return date.toLocaleString('zh-CN');
}

function getRoleName(role) {
    const names = {
        super_admin: '超级管理员',
        admin: '管理员',
        operator: '操作员',
        viewer: '查看者'
    };
    return names[role] || role;
}

function debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
        const later = () => {
            clearTimeout(timeout);
            func(...args);
        };
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
    };
}
