import { defineConfig } from '@playwright/test';
import path from 'node:path';

const apiBaseURL = 'http://127.0.0.1:8765';
const pythonExecutable = path.resolve(
  __dirname,
  '../../backend/.venv/Scripts/python.exe',
);

export default defineConfig({
  testDir: './tests',
  fullyParallel: false,
  workers: 1,
  retries: 0,
  timeout: 30_000,
  expect: { timeout: 5_000 },
  reporter: [
    ['list'],
    ['json', { outputFile: 'test-results/report.json' }],
  ],
  outputDir: 'test-results/artifacts',
  use: {
    baseURL: apiBaseURL,
    extraHTTPHeaders: { Accept: 'application/json' },
    trace: 'retain-on-failure',
  },
  webServer: {
    command: `"${pythonExecutable}" qa_server.py`,
    cwd: __dirname,
    url: `${apiBaseURL}/admin/login/`,
    reuseExistingServer: false,
    timeout: 120_000,
    stdout: 'pipe',
    stderr: 'pipe',
  },
});
