export class AppError extends Error {
  readonly statusCode: number;

  constructor(message: string, statusCode = 500) {
    super(message);
    this.name = "AppError";
    this.statusCode = statusCode;
  }
}

export class ForbiddenAppError extends AppError {
  constructor(message = "Forbidden") {
    super(message, 403);
    this.name = "ForbiddenAppError";
  }
}

export const ForbiddenError = (message = "Forbidden") => new ForbiddenAppError(message);
