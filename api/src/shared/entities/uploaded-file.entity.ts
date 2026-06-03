import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
  OneToMany,
} from 'typeorm';
import { User } from './user.entity';
import { Transaction } from './transaction.entity';

export enum ParseStatus {
  PENDING = 'pending',
  PROCESSING = 'processing',
  COMPLETED = 'completed',
  FAILED = 'failed',
}

@Entity('uploaded_files')
export class UploadedFile {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'user_id' })
  userId: number;

  @Column({ length: 255 })
  filename: string;

  @Column({ name: 'file_size_kb', type: 'int' })
  fileSizeKb: number;

  @Column({ name: 'storage_path', type: 'text' })
  storagePath: string;

  @Column({
    name: 'parse_status',
    type: 'enum',
    enum: ParseStatus,
    default: ParseStatus.PENDING,
  })
  parseStatus: ParseStatus;

  @Column({ name: 'records_parsed', type: 'int', default: 0 })
  recordsParsed: number;

  @Column({ name: 'created_by' })
  createdBy: number;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @Column({ name: 'uploaded_at', type: 'datetime', nullable: true })
  uploadedAt: Date;

  @ManyToOne(() => User, (user) => user.uploadedFiles)
  @JoinColumn({ name: 'user_id' })
  user: User;

  @OneToMany(() => Transaction, (transaction) => transaction.file)
  transactions: Transaction[];
}
