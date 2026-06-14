// Component object for an Element Plus el-select.
//
// Two EP facts drive this design (Q3):
//  - The dropdown options render in a body-level overlay (.el-select-dropdown),
//    NOT inside the trigger — so option clicks are scoped to the page.
//  - An el-form-item's <label> is a sibling of the control and is not
//    associated (no for/id) with the el-select (which is a <div>, not a native
//    input), so getByLabel cannot target it. We scope by the form-item's
//    visible label text instead.

export class Select {
  // `trigger` is a Locator for the .el-select element to open.
  constructor(page, trigger) {
    this.page = page;
    this.trigger = trigger;
  }

  // A Select scoped to an el-form-item by its visible label, within a
  // form/dialog `scope` Locator. e.g. Select.inForm(dialog, 'Roles').
  static inForm(scope, label) {
    const trigger = scope.locator('.el-form-item', { hasText: label }).locator('.el-select');
    return new Select(scope.page(), trigger);
  }

  // Open the dropdown and click an option by its text.
  async #open(optionText) {
    await this.trigger.click();
    await this.page.locator('.el-select-dropdown__item', { hasText: optionText }).click();
  }

  // Single-select: pick one option (the overlay auto-closes on click).
  async choose(optionText) {
    await this.#open(optionText);
  }

  // Multi-select: add an option, then dismiss the still-open overlay so a
  // following footer button (Confirm, etc.) is clickable.
  async add(optionText) {
    await this.#open(optionText);
    await this.page.keyboard.press('Escape');
  }
}
