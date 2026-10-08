import { SampleDatabase } from '../storage/SampleDatabase';
import { StorageManager } from '../storage/StorageManager';
import { common } from '@kit.AbilityKit';

@Entry
@ComponentV2
struct Index {
  private static readonly SAMPLE_BYTES: number = 4 * 1024;
  private db: SampleDatabase = SampleDatabase.getInstance();
  private manager: StorageManager = StorageManager.getInstance();
  @Local usedBytes: number = 0;
  @Local sampleCount: number = 0;
  @Local autoClear: boolean = true;
  @Local status: string = 'Add sample data to grow the database.';

  aboutToAppear(): void {
    this.setup();
  }

  build() {
    Column({ space: 5 }) {
      Row({ space: 8 }) {
        Text('Auto-clear')
          .fontSize(12)
          .layoutWeight(1)
          .textAlign(TextAlign.Start)
        Toggle({ type: ToggleType.Switch, isOn: this.autoClear })
          .enabled(!this.manager.isForcedOn(this.usedBytes))
          .onChange((on: boolean) => {
            this.onToggle(on);
          })
      }
      .width('80%')

      Button('Add 4 KB sample')
        .width('80%')
        .fontSize(12)
        .onClick(() => {
          this.addSample();
        })

      Button('Clear all')
        .width('80%')
        .fontSize(12)
        .onClick(() => {
          this.clearAll();
        })

      Text(this.status)
        .fontSize(12)
        .fontColor(Color.Gray)
        .width('80%')
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding(16)
  }

  private async setup(): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.Context;
    await this.db.init(context);
    await this.refresh('');
  }

  // Inserting sample data auto-clears when the toggle is on (the "auto" in auto-clear).
  private async addSample(): Promise<void> {
    const ok: boolean = await this.db.insertSample(Index.SAMPLE_BYTES);
    let note: string = ok ? 'Added 4 KB' : 'Insert failed';
    if (this.manager.isAutoClearEnabled()) {
      const freed: number = await this.manager.enforce();
      if (freed > 0) {
        note = `Added 4 KB, auto-cleared ${Math.round(freed / 1024)} KB`;
      }
    }
    await this.refresh(note);
  }

  private async clearAll(): Promise<void> {
    await this.db.clear();
    await this.refresh('Cleared all');
  }

  private async onToggle(on: boolean): Promise<void> {
    this.manager.setAutoClear(on, this.usedBytes);
    await this.refresh('');
  }

  private async refresh(note: string): Promise<void> {
    this.usedBytes = await this.db.totalBytes();
    this.sampleCount = await this.db.count();
    const forced: boolean = this.manager.isForcedOn(this.usedBytes);
    // Below the limit the toggle reflects the stored value; over it, it's locked on.
    this.autoClear = forced ? true : this.manager.isAutoClearEnabled();
    const usedKb: number = Math.round(this.usedBytes / 1024);
    const limitKb: number = Math.round(StorageManager.LIMIT_BYTES / 1024);
    const head: string = `${usedKb}/${limitKb} KB in ${this.sampleCount} rows${forced ? ' — over limit' : ''}`;
    this.status = note.length > 0 ? `${head}\n${note}` : head;
  }
}