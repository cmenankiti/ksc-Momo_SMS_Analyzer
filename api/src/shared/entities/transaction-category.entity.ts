import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  OneToMany,
} from 'typeorm';
import { Transaction } from './transaction.entity';

@Entity('transaction_categories')
export class TransactionCategory {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'category_name', length: 50 })
  categoryName: string;

  @Column({ name: 'is_income', type: 'tinyint', default: 0 })
  isIncome: number;

  @Column({ length: 500, nullable: true })
  description: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @OneToMany(() => Transaction, (transaction) => transaction.category)
  transactions: Transaction[];
}
