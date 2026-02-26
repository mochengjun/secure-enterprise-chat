# 功能更新说明

## 更新日期：2026-02-23

### 1. 北京时间显示功能

#### 功能描述
将所有消息时间统一转换为北京时间（Asia/Shanghai）格式显示，无论用户在哪个时区，都能看到统一的北京时间。

#### 实现细节

**新增时间工具函数** (`src/shared/utils/timeUtils.ts`):

- `formatToBeijingTime(date)` - 转换为北京时间 HH:mm 格式
- `formatToBeijingDateTime(date)` - 转换为北京时间完整格式 YYYY-MM-DD HH:mm:ss
- `formatToBeijingDate(date)` - 转换为北京日期格式 YYYY-MM-DD
- `formatRelativeTime(date)` - 相对时间显示（如"5分钟前"）
- `getBeijingTime()` - 获取北京时区的当前时间
- `isSameDayBeijing(date1, date2)` - 检查两个时间是否是同一天（北京时间）
- `formatChatMessageTime(date)` - 智能聊天时间显示

**智能时间显示规则**:
- 今天：显示 HH:mm
- 昨天：显示 "昨天 HH:mm"
- 本周其他天：显示 "周X HH:mm"
- 更早：显示 "YYYY-MM-DD HH:mm"

**修改的文件**:
- `src/presentation/pages/chat/ChatRoomPage.tsx` - 消息列表时间显示
- `src/shared/utils/timeUtils.ts` - 新增时间工具函数

**使用示例**:
```typescript
import { formatChatMessageTime, formatToBeijingDateTime } from '@shared/utils/timeUtils';

// 在消息时间提示中
<Tooltip title={formatToBeijingDateTime(msg.createdAt)}>
  <span>{formatChatMessageTime(msg.createdAt)}</span>
</Tooltip>
```

### 2. 多终端同时登录功能

#### 功能描述
支持同一账号在多个设备上同时登录，并在各设备间保持数据同步。

#### 实现细节

**新增设备管理** (`src/core/storage/DeviceStorage.ts`):

- 每个设备有唯一的设备ID
- 自动识别设备类型（PC、移动端）和浏览器
- 跟踪设备最后活跃时间
- 支持多设备同时在线

**设备信息结构**:
```typescript
interface DeviceInfo {
  deviceId: string;      // 唯一设备ID
  deviceName: string;    // 设备名称（如"Windows PC (Chrome)"）
  lastActive: number;    // 最后活跃时间戳
}
```

**认证流程改进**:
- 登录时自动生成或获取设备ID
- 在登录请求中附带 device_id 参数
- 不强制登出其他设备
- 支持多个设备同时连接WebSocket

**修改的文件**:
- `src/core/storage/DeviceStorage.ts` - 新增设备存储管理
- `src/presentation/stores/authStore.ts` - 认证流程支持设备ID
- `src/shared/types/api.types.ts` - LoginRequest 添加 device_id 字段

**使用示例**:
```typescript
import { getDeviceId, updateDeviceActivity } from '@core/storage/DeviceStorage';

// 获取设备ID
const deviceId = getDeviceId();

// 更新设备活跃时间
updateDeviceActivity();
```

#### 技术说明

1. **设备ID生成**:
   - 使用随机字符串 + 时间戳组合生成唯一ID
   - 存储在 localStorage 中，持久化保存

2. **设备名称识别**:
   - 自动检测设备类型（移动端/PC）
   - 识别操作系统（Windows/Mac/Linux）
   - 识别浏览器（Chrome/Firefox/Safari/Edge）

3. **多设备同步**:
   - 每个设备维护独立的WebSocket连接
   - 消息通过WebSocket实时推送到所有在线设备
   - 设备间不相互干扰

4. **兼容性**:
   - 兼容现有后端API（device_id为可选参数）
   - 后端支持设备ID时自动启用多设备功能
   - 后端不支持时降级为单设备模式

### 3. 技术栈

- **时间处理**: dayjs + timezone 插件
- **设备识别**: UserAgent 解析
- **状态管理**: Zustand + persist 中间件
- **WebSocket**: 自定义WebSocket客户端

### 4. 测试建议

#### 北京时间显示测试
1. 在不同时区访问应用（可通过修改系统时区）
2. 验证消息时间是否显示为北京时间
3. 检查日期分隔符是否正确
4. 测试智能时间显示（今天、昨天、本周等）

#### 多设备登录测试
1. 在同一浏览器的不同标签页登录
2. 在不同浏览器（Chrome、Firefox）中登录同一账号
3. 在不同设备（PC、手机）上登录同一账号
4. 验证消息是否在所有设备上实时同步
5. 测试设备间的状态隔离

### 5. 注意事项

1. **时区依赖**:
   - 需要确保 dayjs 的 timezone 插件正确加载
   - 浏览器需要支持 Intl API（现代浏览器均支持）

2. **设备存储**:
   - 设备ID存储在 localStorage，清除缓存会重新生成
   - 隐私模式下设备ID无法持久化

3. **后端兼容性**:
   - device_id 参数为可选，不影响现有功能
   - 建议后端也支持 device_id 以获得完整的跨设备同步体验

4. **网络环境**:
   - WebSocket需要稳定的网络连接
   - 多设备同时在线会增加服务器负载

### 6. 未来优化方向

1. **设备管理**:
   - 显示当前账号所有在线设备
   - 支持远程登出指定设备
   - 设备历史记录

2. **时间设置**:
   - 允许用户自定义显示时区
   - 提供24/12小时制切换
   - 时间格式本地化

3. **同步优化**:
   - 离线消息同步
   - 冲突解决机制
   - 增量同步优化

---

## 版本信息

- **前端版本**: 1.0.1
- **更新内容**: 北京时间显示、多设备登录支持
- **向后兼容**: 是
