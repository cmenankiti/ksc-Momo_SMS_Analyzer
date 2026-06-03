import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { User } from '../entities/user.entity';
import { UploadedFile } from '../entities/uploaded-file.entity';
import { TransactionCategory } from '../entities/transaction-category.entity';
import { Transaction } from '../entities/transaction.entity';
import { Tag } from '../entities/tag.entity';
import { TransactionTag } from '../entities/transaction-tag.entity';
import { SystemLog } from '../entities/system-log.entity';

@Module({
  imports: [
    TypeOrmModule.forRoot({
      type: 'mysql',
      host: process.env.DB_HOST || 'localhost',
      port: parseInt(process.env.DB_PORT || '3306', 10),
      username: process.env.DB_USERNAME || 'root',
      password: process.env.DB_PASSWORD || '',
      database: process.env.DB_DATABASE || 'momo_sms_analyser',
      entities: [
        User,
        UploadedFile,
        TransactionCategory,
        Transaction,
        Tag,
        TransactionTag,
        SystemLog,
      ],
      synchronize: process.env.NODE_ENV !== 'production',
      logging: process.env.DB_LOGGING === 'true',
    }),
  ],
  exports: [TypeOrmModule],
})
export class DatabaseModule {}
