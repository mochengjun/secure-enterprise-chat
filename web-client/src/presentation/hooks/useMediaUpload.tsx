import { useState, useCallback } from 'react';
import { Upload, message, Progress } from 'antd';
import type { UploadFile, RcFile } from 'antd/es/upload/interface';
import { apiClient } from '@core/api/client';
import { ENDPOINTS } from '@core/api/endpoints';
import type { MediaUploadResponse } from '@shared/types/api.types';

interface UseMediaUploadOptions {
  maxSize?: number; // 最大文件大小（MB）
  acceptTypes?: string[]; // 允许的文件类型
  onSuccess?: (media: MediaUploadResponse) => void;
  onError?: (error: Error) => void;
}

interface UseMediaUploadReturn {
  uploading: boolean;
  progress: number;
  uploadFile: (file: RcFile) => Promise<MediaUploadResponse | null>;
  fileList: UploadFile[];
  setFileList: React.Dispatch<React.SetStateAction<UploadFile[]>>;
  clearFiles: () => void;
}

const CHUNK_SIZE = 5 * 1024 * 1024; // 5MB分片大小

export function useMediaUpload(options: UseMediaUploadOptions = {}): UseMediaUploadReturn {
  const {
    maxSize = 100, // 默认100MB
    acceptTypes = ['image/*', 'video/*', 'audio/*', 'application/pdf', '.doc', '.docx', '.xls', '.xlsx'],
    onSuccess,
    onError,
  } = options;

  const [uploading, setUploading] = useState(false);
  const [progress, setProgress] = useState(0);
  const [fileList, setFileList] = useState<UploadFile[]>([]);

  // 验证文件
  const validateFile = useCallback((file: RcFile): boolean => {
    // 检查文件大小
    const isLt = file.size / 1024 / 1024 < maxSize;
    if (!isLt) {
      message.error(`文件大小不能超过 ${maxSize}MB`);
      return false;
    }

    // 检查文件类型
    const isValidType = acceptTypes.some(type => {
      if (type.startsWith('.')) {
        return file.name.toLowerCase().endsWith(type.toLowerCase());
      }
      if (type.endsWith('/*')) {
        const baseType = type.replace('/*', '');
        return file.type.startsWith(baseType);
      }
      return file.type === type;
    });

    if (!isValidType) {
      message.error('不支持的文件类型');
      return false;
    }

    return true;
  }, [maxSize, acceptTypes]);

  // 普通上传（小文件）
  const uploadSmallFile = async (file: RcFile): Promise<MediaUploadResponse> => {
    const formData = new FormData();
    formData.append('file', file);

    const response = await apiClient.post<MediaUploadResponse>(
      ENDPOINTS.MEDIA.UPLOAD,
      formData,
      {
        headers: {
          'Content-Type': 'multipart/form-data',
        },
        onUploadProgress: (progressEvent) => {
          if (progressEvent.total) {
            const percent = Math.round((progressEvent.loaded * 100) / progressEvent.total);
            setProgress(percent);
          }
        },
      }
    );

    return response.data;
  };

  // 分片上传（大文件）
  const uploadLargeFile = async (file: RcFile): Promise<MediaUploadResponse> => {
    const totalChunks = Math.ceil(file.size / CHUNK_SIZE);
    
    // 初始化上传会话
    const initResponse = await apiClient.post<{ session_id: string }>(
      ENDPOINTS.MEDIA.CHUNKED_INIT,
      {
        filename: file.name,
        size: file.size,
        mime_type: file.type,
        total_chunks: totalChunks,
      }
    );
    
    const sessionId = initResponse.data.session_id;
    
    // 上传每个分片
    for (let i = 0; i < totalChunks; i++) {
      const start = i * CHUNK_SIZE;
      const end = Math.min(start + CHUNK_SIZE, file.size);
      const chunk = file.slice(start, end);
      
      const chunkFormData = new FormData();
      chunkFormData.append('chunk', chunk);
      
      await apiClient.post(
        ENDPOINTS.MEDIA.CHUNKED_CHUNK(sessionId, i),
        chunkFormData,
        {
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        }
      );
      
      // 更新进度
      setProgress(Math.round(((i + 1) / totalChunks) * 100));
    }
    
    // 完成上传
    const completeResponse = await apiClient.post<MediaUploadResponse>(
      ENDPOINTS.MEDIA.CHUNKED_COMPLETE(sessionId)
    );
    
    return completeResponse.data;
  };

  // 上传文件
  const uploadFile = useCallback(async (file: RcFile): Promise<MediaUploadResponse | null> => {
    if (!validateFile(file)) {
      return null;
    }

    setUploading(true);
    setProgress(0);

    try {
      let result: MediaUploadResponse;
      
      // 大于10MB使用分片上传
      if (file.size > 10 * 1024 * 1024) {
        result = await uploadLargeFile(file);
      } else {
        result = await uploadSmallFile(file);
      }

      message.success('文件上传成功');
      onSuccess?.(result);
      return result;
    } catch (error) {
      const err = error instanceof Error ? error : new Error('上传失败');
      message.error(err.message);
      onError?.(err);
      return null;
    } finally {
      setUploading(false);
      setProgress(0);
    }
  }, [validateFile, onSuccess, onError]);

  // 清除文件列表
  const clearFiles = useCallback(() => {
    setFileList([]);
    setProgress(0);
  }, []);

  return {
    uploading,
    progress,
    uploadFile,
    fileList,
    setFileList,
    clearFiles,
  };
}

// 媒体上传组件
interface MediaUploaderProps {
  onUploadSuccess?: (media: MediaUploadResponse) => void;
  accept?: string;
  maxSize?: number;
  children?: React.ReactNode;
}

export function MediaUploader({
  onUploadSuccess,
  accept = 'image/*,video/*,audio/*,.pdf,.doc,.docx',
  maxSize = 100,
  children,
}: MediaUploaderProps) {
  const { uploading, progress, uploadFile, fileList, setFileList } = useMediaUpload({
    maxSize,
    onSuccess: onUploadSuccess,
  });

  const handleBeforeUpload = async (file: RcFile) => {
    await uploadFile(file);
    return false; // 阻止默认上传行为
  };

  return (
    <Upload
      accept={accept}
      fileList={fileList}
      onChange={({ fileList: newFileList }) => setFileList(newFileList)}
      beforeUpload={handleBeforeUpload}
      showUploadList={false}
    >
      {children}
      {uploading && (
        <Progress
          percent={progress}
          size="small"
          style={{ marginTop: 8 }}
        />
      )}
    </Upload>
  );
}
