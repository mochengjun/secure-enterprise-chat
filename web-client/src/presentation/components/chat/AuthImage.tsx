import { useState, useEffect, useRef } from 'react';
import { Spin } from 'antd';
import { LoadingOutlined, PictureOutlined } from '@ant-design/icons';
import { apiClient } from '@core/api/client';
import { API_CONFIG } from '@shared/constants/config';

interface AuthImageProps {
  src?: string;
  alt?: string;
  style?: React.CSSProperties;
  onClick?: () => void;
}

export default function AuthImage({ src, alt = '', style, onClick }: AuthImageProps) {
  const [blobUrl, setBlobUrl] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(false);
  const blobUrlRef = useRef<string | null>(null);

  useEffect(() => {
    if (!src) {
      setLoading(false);
      setError(true);
      return;
    }

    let cancelled = false;

    const fetchImage = async () => {
      setLoading(true);
      setError(false);
      try {
        // 处理URL：如果src已经包含完整的API路径（以/api/v1开头），
        // 需要去掉重复的前缀，因为apiClient已经设置了baseURL为/api/v1
        let requestUrl = src;
        const baseUrl = API_CONFIG.BASE_URL; // 通常是 /api/v1
        if (requestUrl.startsWith(baseUrl + '/')) {
          // 去掉重复的 /api/v1 前缀
          requestUrl = requestUrl.substring(baseUrl.length);
        }
        
        const response = await apiClient.get(requestUrl, { responseType: 'blob' });
        if (cancelled) return;
        const url = URL.createObjectURL(response.data);
        blobUrlRef.current = url;
        setBlobUrl(url);
      } catch (e) {
        console.error('AuthImage fetch error:', e, 'src:', src);
        if (!cancelled) setError(true);
      } finally {
        if (!cancelled) setLoading(false);
      }
    };

    fetchImage();

    return () => {
      cancelled = true;
      if (blobUrlRef.current) {
        URL.revokeObjectURL(blobUrlRef.current);
        blobUrlRef.current = null;
      }
    };
  }, [src]);

  if (loading) {
    return (
      <div style={{ width: 200, height: 120, display: 'flex', alignItems: 'center', justifyContent: 'center', background: '#f5f5f5', borderRadius: 8, ...style }}>
        <Spin indicator={<LoadingOutlined />} />
      </div>
    );
  }

  if (error || !blobUrl) {
    return (
      <div style={{ width: 200, height: 80, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 4, background: '#f5f5f5', borderRadius: 8, color: '#999', fontSize: 12, ...style }}>
        <PictureOutlined /> 图片加载失败
      </div>
    );
  }

  return (
    <img
      src={blobUrl}
      alt={alt}
      style={{ maxWidth: 200, maxHeight: 200, borderRadius: 8, objectFit: 'cover', cursor: onClick ? 'pointer' : undefined, ...style }}
      onClick={onClick}
    />
  );
}
