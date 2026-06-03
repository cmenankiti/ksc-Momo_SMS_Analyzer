import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { Transaction } from './transaction.entity';
import { Tag } from './tag.entity';
import { User } from './user.entity';

@Entity('transaction_tags')
export class TransactionTag {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'transaction_id' })
  transactionId: number;

  @Column({ name: 'tag_id' })
  tagId: number;

  @Column({ name: 'tagged_by' })
  taggedBy: number;

  @CreateDateColumn({ name: 'tagged_at' })
  taggedAt: Date;

  @ManyToOne(() => Transaction, (transaction) => transaction.transactionTags)
  @JoinColumn({ name: 'transaction_id' })
  transaction: Transaction;

  @ManyToOne(() => Tag, (tag) => tag.transactionTags)
  @JoinColumn({ name: 'tag_id' })
  tag: Tag;

  @ManyToOne(() => User, (user) => user.transactionTags)
  @JoinColumn({ name: 'tagged_by' })
  taggedByUser: User;
}
