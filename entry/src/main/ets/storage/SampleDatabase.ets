import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

const TABLE: string = 'samples';
const CREATE_SQL: string =
  `CREATE TABLE IF NOT EXISTS ${TABLE} (id INTEGER PRIMARY KEY AUTOINCREMENT, created INTEGER, data BLOB)`;

interface OldestRow {
  id: number;
  size: number;
}

/**
 * Sample data in a local RDB database (relationalStore), living in the app
 * sandbox. Each row carries a `data` BLOB, so the database's byte size is the
 * total length of those blobs.
 */
export class SampleDatabase {
  private static instance: SampleDatabase;
  private store?: relationalStore.RdbStore;

  static getInstance(): SampleDatabase {
    if (!SampleDatabase.instance) {
      SampleDatabase.instance = new SampleDatabase();
    }
    return SampleDatabase.instance;
  }

  async init(context: common.Context): Promise<void> {
    if (this.store !== undefined) {
      return;
    }
    const config: relationalStore.StoreConfig = {
      name: 'samples.db',
      securityLevel: relationalStore.SecurityLevel.S1
    };
    try {
      this.store = await relationalStore.getRdbStore(context, config);
      await this.store.executeSql(CREATE_SQL);
    } catch (err) {
      SampleDatabase.logErr('init', err);
    }
  }

  /** Inserts one row carrying `sizeBytes` of data. Returns true on success. */
  async insertSample(sizeBytes: number): Promise<boolean> {
    if (this.store === undefined) {
      return false;
    }
    const values: relationalStore.ValuesBucket = {
      'created': Date.now(),
      'data': new Uint8Array(sizeBytes)
    };
    try {
      await this.store.insert(TABLE, values);
      return true;
    } catch (err) {
      SampleDatabase.logErr('insertSample', err);
      return false;
    }
  }

  /** Total bytes of all stored sample data (sum of blob lengths). */
  async totalBytes(): Promise<number> {
    if (this.store === undefined) {
      return 0;
    }
    try {
      const rs = await this.store.querySql(`SELECT CAST(total(length(data)) AS INTEGER) AS bytes FROM ${TABLE}`);
      let bytes: number = 0;
      if (rs.goToFirstRow()) {
        bytes = rs.getLong(rs.getColumnIndex('bytes'));
      }
      rs.close();
      return bytes;
    } catch (err) {
      SampleDatabase.logErr('totalBytes', err);
      return 0;
    }
  }

  async count(): Promise<number> {
    if (this.store === undefined) {
      return 0;
    }
    try {
      const rs = await this.store.querySql(`SELECT count(*) AS n FROM ${TABLE}`);
      let n: number = 0;
      if (rs.goToFirstRow()) {
        n = rs.getLong(rs.getColumnIndex('n'));
      }
      rs.close();
      return n;
    } catch (err) {
      SampleDatabase.logErr('count', err);
      return 0;
    }
  }

  /** Deletes the oldest rows until total data bytes are at or below limitBytes. Returns bytes freed. */
  async evictUntilUnder(limitBytes: number): Promise<number> {
    if (this.store === undefined) {
      return 0;
    }
    try {
      const rows: OldestRow[] = [];
      let remaining: number = 0;
      const rs = await this.store.querySql(`SELECT id, length(data) AS size FROM ${TABLE} ORDER BY created ASC, id ASC`);
      while (rs.goToNextRow()) {
        const id: number = rs.getLong(rs.getColumnIndex('id'));
        const size: number = rs.getLong(rs.getColumnIndex('size'));
        rows.push({ id, size });
        remaining += size;
      }
      rs.close();
      let freed: number = 0;
      for (let i = 0; i < rows.length && remaining > limitBytes; i++) {
        await this.deleteById(rows[i].id);
        remaining -= rows[i].size;
        freed += rows[i].size;
      }
      return freed;
    } catch (err) {
      SampleDatabase.logErr('evictUntilUnder', err);
      return 0;
    }
  }

  /** Deletes all rows. */
  async clear(): Promise<void> {
    if (this.store === undefined) {
      return;
    }
    try {
      await this.store.executeSql(`DELETE FROM ${TABLE}`);
    } catch (err) {
      SampleDatabase.logErr('clear', err);
    }
  }

  private async deleteById(id: number): Promise<void> {
    if (this.store === undefined) {
      return;
    }
    try {
      const predicates = new relationalStore.RdbPredicates(TABLE);
      predicates.equalTo('id', id);
      await this.store.delete(predicates);
    } catch (err) {
      SampleDatabase.logErr('deleteById', err);
    }
  }

  private static logErr(where: string, err: Object): void {
    const e = err as BusinessError;
    console.error(`SampleDatabase ${where} failed: ${e.code} - ${e.message}`);
  }
}
