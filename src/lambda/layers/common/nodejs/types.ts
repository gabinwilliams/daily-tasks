export type TaskStatus = 'pending' | 'completed' | 'approved' | 'rejected';

export interface Task {
  taskId: string;
  kidId: string;
  title: string;
  description: string;
  status: TaskStatus;
  dueDate: string;
  photoUrl?: string;
  parentComment?: string;
  createdBy: string;
  createdAt: string;
  updatedAt: string;
}

export interface CreateTaskInput {
  kidId: string;
  title: string;
  description: string;
  dueDate: string;
}

export interface UpdateTaskInput {
  title?: string;
  description?: string;
  status?: TaskStatus;
  photoUrl?: string;
  parentComment?: string;
}

export interface TaskQueryParams {
  kidId?: string;
  status?: TaskStatus;
  fromDate?: string;
  toDate?: string;
}

export interface UploadPhotoInput {
  taskId: string;
  contentType: string;
} 