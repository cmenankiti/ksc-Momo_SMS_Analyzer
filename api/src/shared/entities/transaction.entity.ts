import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
  OneToMany,
} from 'typeorm';
import { UploadedFile } from './uploaded-file.entity';
import { User } from './user.entity';
import { TransactionCategory } from './transaction-category.entity';
import { TransactionTag } from './transaction-tag.entity';
import { SystemLog } from './system-log.entity';

export enum TransactionType {
  INCOMING = 'Incoming',
  TRANSFER = 'Transfer',
  WITHDRAWAL = 'Withdrawal',
  PAYMENT = 'Payment',
  AIRTIME = 'Airtime',
  BANK_DEPOSIT = 'Bank_Deposit',
  BUNDLE_PURCHASE = 'Bundle_Purchase',
}

export enum TransactionStatus {
  PENDING = 'Pending',
  COMPLETED = 'Completed',
  FAILED = 'Failed',
}

@Entity('transactions')
export class Transaction {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'file_id', default: null })
  fileId: number;

  @Column({ name: 'sender_id', nullable: true, default: null })
  senderId: number;

  @Column({ name: 'receiver_id', nullable: true, default: null })
  receiverId: number;

  @Column({ name: 'category_id', nullable: true })
  categoryId: number;

  @Column({ type: 'decimal', precision: 12, scale: 2 })
  amount: number;

  @Column({ type: 'decimal', precision: 12, scale: 2, default: 0 })
  fee: number;

  @Column({
    name: 'balance_after',
    type: 'decimal',
    precision: 10,
    scale: 2,
    nullable: true,
  })
  balanceAfter: number;

  @Column({
    name: 'transaction_type',
    type: 'enum',
    enum: TransactionType,
  })
  transactionType: TransactionType;

  @Column({
    name: 'transaction_status',
    type: 'enum',
    enum: TransactionStatus,
    default: TransactionStatus.PENDING,
  })
  transactionStatus: TransactionStatus;

  @Column({
    name: 'external_transaction_id',
    length: 100,
    nullable: true,
  })
  externalTransactionId: string;

  @Column({ name: 'sender_name', length: 100, nullable: true })
  senderName: string;

  @Column({ name: 'receiver_name', length: 100, nullable: true })
  receiverName: string;

  @Column({ name: 'error_message', type: 'text', nullable: true })
  errorMessage: string;

  @Column({ name: 'transaction_date', type: 'datetime' })
  transactionDate: Date;

  @Column({ name: 'raw_message', type: 'text', nullable: true })
  rawMessage: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;

  @ManyToOne(() => UploadedFile, (file) => file.transactions)
  @JoinColumn({ name: 'file_id' })
  file: UploadedFile;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'sender_id' })
  sender: User;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'receiver_id' })
  receiver: User;

  @ManyToOne(() => TransactionCategory, (category) => category.transactions)
  @JoinColumn({ name: 'category_id' })
  category: TransactionCategory;

  @OneToMany(() => TransactionTag, (tt) => tt.transaction)
  transactionTags: TransactionTag[];

  @OneToMany(() => SystemLog, (log) => log.transaction)
  systemLogs: SystemLog[];
}
