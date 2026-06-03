import { IsEmail, IsString, MinLength, MaxLength, IsOptional, IsEnum } from 'class-validator';
import { UserRole } from '../../shared/entities/user.entity';

export class RegisterDto {
  @IsString()
  @MinLength(2)
  @MaxLength(100)
  fullName: string;

  @IsString()
  @MinLength(10)
  @MaxLength(20)
  phoneNumber: string;

  @IsEmail()
  @MaxLength(100)
  email: string;

  @IsString()
  @MinLength(6)
  @MaxLength(200)
  password: string;

  @IsOptional()
  @IsEnum(UserRole)
  role?: UserRole;
}

