import {
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, FindOptionsWhere, Between, Like } from 'typeorm';
import { Transaction } from '../shared/entities/transaction.entity';
import { CreateTransactionDto } from './dto/create-transaction.dto';

@Injectable()
export class TransactionsService {
  constructor(
    @InjectRepository(Transaction)
    private transactionRepository: Repository<Transaction>,
  ) {}

  async findAll(
    query: {
      page?: number;
      limit?: number;
      transactionType?: string;
      transactionStatus?: string;
      startDate?: string;
      endDate?: string;
      search?: string;
    } = {},
  ): Promise<{ data: Transaction[]; total: number; page: number; limit: number }> {
    const page = query.page || 1;
    const limit = query.limit || 20;
    const skip = (page - 1) * limit;

    const where: FindOptionsWhere<Transaction> = {};

    if (query.transactionType) {
      where.transactionType = query.transactionType as any;
    }
    if (query.transactionStatus) {
      where.transactionStatus = query.transactionStatus as any;
    }
    if (query.startDate && query.endDate) {
      where.transactionDate = Between(
        new Date(query.startDate),
        new Date(query.endDate),
      );
    }
    if (query.search) {
      where.senderName = Like(`%${query.search}%`);
    }

    const [data, total] = await this.transactionRepository.findAndCount({
      where,
      relations: { category: true, sender: true, receiver: true },
      order: { transactionDate: 'DESC' },
      skip,
      take: limit,
    });

    return {
      data,
      total,
      page,
      limit,
      ...(total === 0 && { message: 'No transactions found' }),
    };
  }

  async findOne(id: number): Promise<Transaction> {
    const transaction = await this.transactionRepository.findOne({
      where: { id },
      relations: {
        category: true,
        sender: true,
        receiver: true,
        file: true,
        transactionTags: { tag: true },
      },
    });
    if (!transaction) {
      throw new NotFoundException(`Transaction #${id} not found`);
    }
    return transaction;
  }

  async create(dto: CreateTransactionDto): Promise<Transaction> {
    const transaction = this.transactionRepository.create({
      ...dto,
      transactionDate: new Date(dto.transactionDate),
    });
    return this.transactionRepository.save(transaction);
  }

  async update(
    id: number,
    updateData: Partial<Transaction>,
  ): Promise<Transaction> {
    const transaction = await this.findOne(id);
    Object.assign(transaction, updateData);
    return this.transactionRepository.save(transaction);
  }

  async remove(id: number): Promise<void> {
    const transaction = await this.findOne(id);
    await this.transactionRepository.remove(transaction);
  }

  async getStats(): Promise<any> {
    const total = await this.transactionRepository.count();
    const totalAmount = await this.transactionRepository
      .createQueryBuilder('t')
      .select('SUM(t.amount)', 'total')
      .getRawOne();

    const byType = await this.transactionRepository
      .createQueryBuilder('t')
      .select('t.transactionType', 'type')
      .addSelect('COUNT(*)', 'count')
      .addSelect('SUM(t.amount)', 'total')
      .groupBy('t.transactionType')
      .getRawMany();

    const byStatus = await this.transactionRepository
      .createQueryBuilder('t')
      .select('t.transactionStatus', 'status')
      .addSelect('COUNT(*)', 'count')
      .groupBy('t.transactionStatus')
      .getRawMany();

    return { total, totalAmount: totalAmount?.total || 0, byType, byStatus };
  }
}
