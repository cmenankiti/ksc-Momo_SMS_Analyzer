import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { Transaction } from './transaction.entity';
import { User } from './user.entity';

export enum SystemLogStatus {
  SUCCESS = 'Success',
  WARNING = 'Warning',
  ERROR = 'Error',
}

@Entity('system_logs')
export class SystemLog {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'transaction_id', nullable: true })
  transactionId: number;

  @Column({ name: 'user_id', nullable: true })
  userId: number;

  @Column({ name: 'action_type', length: 100 })
  actionType: string;

  @Column({ name: 'log_message', type: 'text' })
  logMessage: string;

  @Column({
    type: 'enum',
    enum: SystemLogStatus,
    default: SystemLogStatus.SUCCESS,
  })
  status: SystemLogStatus;

  @Column({ name: 'ip_address', length: 45, nullable: true })
  ipAddress: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @ManyToOne(() => Transaction, (transaction) => transaction.systemLogs)
  @JoinColumn({ name: 'transaction_id' })
  transaction: Transaction;

  @ManyToOne(() => User, (user) => user.systemLogs)
  @JoinColumn({ name: 'user_id' })
  user: User;
}
