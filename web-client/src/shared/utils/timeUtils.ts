import dayjs from 'dayjs';
import utc from 'dayjs/plugin/utc';
import timezone from 'dayjs/plugin/timezone';

// 扩展dayjs插件
dayjs.extend(utc);
dayjs.extend(timezone);

/**
 * 将时间转换为北京时间并格式化
 * @param date 日期时间
 * @returns 格式化的北京时间字符串
 */
export function formatToBeijingTime(date: Date | string): string {
  return dayjs(date).tz('Asia/Shanghai').format('HH:mm');
}

/**
 * 将时间转换为北京时间完整格式
 * @param date 日期时间
 * @returns 格式化的北京时间字符串 (YYYY-MM-DD HH:mm:ss)
 */
export function formatToBeijingDateTime(date: Date | string): string {
  return dayjs(date).tz('Asia/Shanghai').format('YYYY-MM-DD HH:mm:ss');
}

/**
 * 将时间转换为北京日期
 * @param date 日期时间
 * @returns 格式化的北京日期字符串 (YYYY-MM-DD)
 */
export function formatToBeijingDate(date: Date | string): string {
  return dayjs(date).tz('Asia/Shanghai').format('YYYY-MM-DD');
}

/**
 * 格式化消息时间为相对时间（如"5分钟前"）
 * @param date 日期时间
 * @returns 相对时间字符串
 */
export function formatRelativeTime(date: Date | string): string {
  const now = dayjs().tz('Asia/Shanghai');
  const msgTime = dayjs(date).tz('Asia/Shanghai');
  const diffMinutes = now.diff(msgTime, 'minute');
  
  if (diffMinutes < 1) {
    return '刚刚';
  } else if (diffMinutes < 60) {
    return `${diffMinutes}分钟前`;
  } else if (diffMinutes < 24 * 60) {
    const hours = Math.floor(diffMinutes / 60);
    return `${hours}小时前`;
  } else if (diffMinutes < 7 * 24 * 60) {
    const days = Math.floor(diffMinutes / (24 * 60));
    return `${days}天前`;
  } else {
    // 超过一周显示完整日期
    return msgTime.format('YYYY-MM-DD');
  }
}

/**
 * 获取北京时区的当前时间
 * @returns 北京时区的当前日期对象
 */
export function getBeijingTime(): Date {
  return dayjs().tz('Asia/Shanghai').toDate();
}

/**
 * 检查两个时间是否是同一天（北京时间）
 * @param date1 日期1
 * @param date2 日期2
 * @returns 是否是同一天
 */
export function isSameDayBeijing(date1: Date | string, date2: Date | string): boolean {
  return dayjs(date1).tz('Asia/Shanghai').isSame(dayjs(date2).tz('Asia/Shanghai'), 'day');
}

/**
 * 获取日期分隔符文本（用于消息列表的日期分组）
 * @param date 日期时间
 * @returns 日期分隔符文本
 */
export function getDateSeparatorText(date: Date | string): string {
  const now = dayjs().tz('Asia/Shanghai');
  const msgTime = dayjs(date).tz('Asia/Shanghai');
  
  if (now.isSame(msgTime, 'day')) {
    return '今天';
  } else if (now.subtract(1, 'day').isSame(msgTime, 'day')) {
    return '昨天';
  } else if (now.subtract(7, 'day').isBefore(msgTime)) {
    const weekdays = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    return weekdays[msgTime.day()];
  } else {
    return msgTime.format('YYYY年MM月DD日');
  }
}

/**
 * 格式化房间列表时间（智能显示）
 * - 今天：显示 HH:mm
 * - 昨天：显示 "昨天"
 * - 本周其他天：显示 "周X"
 * - 更早：显示 "MM/DD"
 * @param date 日期时间
 * @returns 格式化的时间字符串
 */
export function formatRoomListTime(date: Date | string): string {
  const now = dayjs().tz('Asia/Shanghai');
  const msgTime = dayjs(date).tz('Asia/Shanghai');
  
  if (now.isSame(msgTime, 'day')) {
    return msgTime.format('HH:mm');
  } else if (now.subtract(1, 'day').isSame(msgTime, 'day')) {
    return '昨天';
  } else if (now.subtract(7, 'day').isBefore(msgTime)) {
    const weekdays = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    return weekdays[msgTime.day()];
  } else {
    return msgTime.format('MM/DD');
  }
}

/**
 * 格式化聊天消息时间（智能显示）
 * - 今天：显示 HH:mm
 * - 昨天：显示 "昨天 HH:mm"
 * - 本周其他天：显示 "周X HH:mm"
 * - 更早：显示 "YYYY-MM-DD HH:mm"
 * @param date 日期时间
 * @returns 格式化的时间字符串
 */
export function formatChatMessageTime(date: Date | string): string {
  const now = dayjs().tz('Asia/Shanghai');
  const msgTime = dayjs(date).tz('Asia/Shanghai');
  
  if (now.isSame(msgTime, 'day')) {
    // 今天
    return msgTime.format('HH:mm');
  } else if (now.subtract(1, 'day').isSame(msgTime, 'day')) {
    // 昨天
    return `昨天 ${msgTime.format('HH:mm')}`;
  } else if (now.subtract(7, 'day').isBefore(msgTime)) {
    // 本周
    const weekdays = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    return `${weekdays[msgTime.day()]} ${msgTime.format('HH:mm')}`;
  } else {
    // 更早
    return msgTime.format('YYYY-MM-DD HH:mm');
  }
}
