import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  OneToMany,
} from 'typeorm';
import { UploadedFile } from './uploaded-file.entity';
import { Tag } from './tag.entity';
import { TransactionTag } from './transaction-tag.entity';
import { SystemLog } from './system-log.entity';

export enum UserRole {
  ADMIN = 'admin',
  ANALYST = 'analyst',
  VIEWER = 'viewer',
}

@Entity('users')
export class User {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'full_name', length: 100 })
  fullName: string;

  @Column({ name: 'phone_number', length: 20 })
  phoneNumber: string;

  @Column({ length: 100 })
  email: string;

  @Column({ length: 200 })
  password: string;

  @Column({ type: 'enum', enum: UserRole, default: UserRole.VIEWER })
  role: UserRole;

  @Column({ name: 'is_active', type: 'tinyint', default: 1 })
  isActive: number;

  @Column({ name: 'token_version', type: 'int', default: 0 })
  tokenVersion: number;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;

  @OneToMany(() => UploadedFile, (file) => file.user)
  uploadedFiles: UploadedFile[];

  @OneToMany(() => Tag, (tag) => tag.createdBy)
  tags: Tag[];

  @OneToMany(() => TransactionTag, (tt) => tt.taggedBy)
  transactionTags: TransactionTag[];

  @OneToMany(() => SystemLog, (log) => log.user)
  systemLogs: SystemLog[];
}
