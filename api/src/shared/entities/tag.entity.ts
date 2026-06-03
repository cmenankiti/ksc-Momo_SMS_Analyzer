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
import { TransactionTag } from './transaction-tag.entity';

@Entity('tags')
export class Tag {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'tag_name', length: 50 })
  tagName: string;

  @Column({ name: 'created_by' })
  createdBy: number;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @ManyToOne(() => User, (user) => user.tags)
  @JoinColumn({ name: 'created_by' })
  createdByUser: User;

  @OneToMany(() => TransactionTag, (tt) => tt.tag)
  transactionTags: TransactionTag[];
}
