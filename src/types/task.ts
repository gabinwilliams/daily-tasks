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
  statusHistory?: Array<{
    status: TaskStatus;
    timestamp: string;
    comment?: string;
  }>;
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
  limit?: number;
  nextToken?: string;
  kidId?: string;
  status?: TaskStatus;
  fromDate?: string;
  toDate?: string;
}

export interface TasksResponse {
  items: Task[];
  nextToken?: string;
}

export interface UploadPhotoInput {
  taskId: string;
  contentType: string;
}

export interface DailyStats {
  date: string;
  totalTasks: number;
  completedTasks: number;
  approvedTasks: number;
}

export interface TaskStats {
  totalTasks: number;
  completedTasks: number;
  approvedTasks: number;
  rejectedTasks: number;
  pendingTasks: number;
  completionRate: number;
  approvalRate: number;
  averageResponseTime: number;
  dailyStats: DailyStats[];
}

export type TimeRange = 'week' | 'month' | 'year'; 