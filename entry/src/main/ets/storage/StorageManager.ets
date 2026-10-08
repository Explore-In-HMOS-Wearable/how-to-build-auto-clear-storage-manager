import { SampleDatabase } from './SampleDatabase';

/**
 * Auto-clear storage manager for the sample database.
 *
 * Keeps the database's stored-data bytes under a limit by deleting the oldest
 * rows (byte-based, oldest-first) when cleanup is enabled. Over the limit the
 * cleanup becomes mandatory and can't be turned off (isForcedOn).
 */
export class StorageManager {
  // Small limit so the demo crosses it quickly (20 KB = five 4 KB samples).
  static readonly LIMIT_BYTES: number = 20 * 1024;
  private static instance: StorageManager;
  private db: SampleDatabase = SampleDatabase.getInstance();
  private autoClear: boolean = true;

  static getInstance(): StorageManager {
    if (!StorageManager.instance) {
      StorageManager.instance = new StorageManager();
    }
    return StorageManager.instance;
  }

  isAutoClearEnabled(): boolean {
    return this.autoClear;
  }

  isForcedOn(usedBytes: number): boolean {
    return usedBytes > StorageManager.LIMIT_BYTES;
  }

  setAutoClear(enabled: boolean, usedBytes: number): void {
    if (!enabled && this.isForcedOn(usedBytes)) {
      return;
    }
    this.autoClear = enabled;
  }

  /** Frees space (oldest rows first) when cleanup is enabled or mandatory. Returns bytes freed. */
  async enforce(): Promise<number> {
    const used: number = await this.db.totalBytes();
    if (!this.autoClear && !this.isForcedOn(used)) {
      return 0;
    }
    return this.db.evictUntilUnder(StorageManager.LIMIT_BYTES);
  }
}
