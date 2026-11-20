const gallery = document.querySelector('[data-gallery]');
if (gallery) {
  const controls = gallery.querySelector('.capture-tabs');
  const buttons = [...controls.querySelectorAll('button[data-capture]')];
  const figures = gallery.querySelectorAll('[data-platform]');

  function select(platform) {
    gallery.dataset.active = platform;
    for (const figure of figures) figure.hidden = figure.dataset.platform !== platform;
    for (const button of buttons) {
      button.setAttribute('aria-pressed', String(button.dataset.capture === platform));
    }
  }

  for (const button of buttons) {
    button.addEventListener('click', () => select(button.dataset.capture));
  }
  select(buttons[0].dataset.capture);
  controls.hidden = false;
}

const licence = document.getElementById('game-assets-licence');
if (licence && typeof HTMLDialogElement !== 'undefined' && HTMLDialogElement.prototype.showModal) {
  const dialog = document.createElement('dialog');
  dialog.className = 'asset-dialog';
  dialog.setAttribute('aria-labelledby', 'game-assets-title');
  dialog.setAttribute('aria-describedby', 'game-assets-terms');
  licence.before(dialog);
  dialog.append(licence);

  const openButton = document.getElementById('get-game-assets');
  const cancelButton = document.getElementById('cancel-game-assets');
  openButton.hidden = false;
  cancelButton.hidden = false;
  cancelButton.autofocus = true;
  openButton.addEventListener('click', () => dialog.showModal());
  cancelButton.addEventListener('click', () => dialog.close());
  licence.querySelector('a').addEventListener('click', () => dialog.close());
}
