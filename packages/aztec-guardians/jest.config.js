module.exports = {
  preset: 'ts-jest',
  testMatch: ['<rootDir>/test/**/*.test.ts'],
  testEnvironment: 'node',
  testTimeout: 30000, // Increased timeout for blockchain operations
  setupFilesAfterEnv: ['./test/setup.ts'],
}; 