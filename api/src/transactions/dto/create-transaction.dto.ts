import {
  IsEnum,
  IsNumber,
  IsDateString,
  IsOptional,
  IsString,
  IsPositive,
  MinLength,
  MaxLength,
} from 'class-validator';
import { TransactionType, TransactionStatus } from '../../shared/entities/transaction.entity';

export class CreateTransactionDto {
  @IsNumber()
  @IsOptional()
  fileId?: number;

  @IsNumber()
  @IsOptional()
  senderId?: number;

  @IsNumber()
  @IsOptional()
  receiverId?: number;

  @IsNumber()
  @IsOptional()
  categoryId?: number;

  @IsNumber()
  @IsPositive()
  amount: number;

  @IsNumber()
  @IsOptional()
  fee?: number;

  @IsNumber()
  @IsOptional()
  balanceAfter?: number;

  @IsEnum(TransactionType)
  transactionType: TransactionType;

  @IsEnum(TransactionStatus)
  @IsOptional()
  transactionStatus?: TransactionStatus;

  @IsString()
  @MaxLength(100)
  @IsOptional()
  externalTransactionId?: string;

  @IsString()
  @MaxLength(100)
  @IsOptional()
  senderName?: string;

  @IsString()
  @MaxLength(100)
  @IsOptional()
  receiverName?: string;

  @IsString()
  @IsOptional()
  errorMessage?: string;

  @IsDateString()
  transactionDate: string;

  @IsString()
  @IsOptional()
  rawMessage?: string;
}
