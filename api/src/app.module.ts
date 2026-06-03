import { Module } from '@nestjs/common';
import { DatabaseModule } from './shared/database/database.module';
import { AuthModule } from './auth/auth.module';
import { TransactionsModule } from './transactions/transactions.module';

@Module({
  imports: [DatabaseModule, AuthModule, TransactionsModule],
  controllers: [],
  providers: [],
})
export class AppModule {}
