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

// Each licence block becomes a modal gate, opened by its matching button.
// Without JavaScript the block stays inline, so the licence still precedes the link.
if (typeof HTMLDialogElement !== 'undefined' && HTMLDialogElement.prototype.showModal) {
  for (const licence of document.querySelectorAll('[data-licence]')) {
    const openButton = document.querySelector(`[data-licence-open="${licence.id}"]`);
    if (!openButton) continue;
    const dialog = document.createElement('dialog');
    dialog.className = 'asset-dialog';
    dialog.setAttribute('aria-labelledby', licence.querySelector('h3').id);
    dialog.setAttribute('aria-describedby', licence.querySelector('p').id);
    licence.before(dialog);
    dialog.append(licence);

    const cancelButton = licence.querySelector('[data-licence-cancel]');
    openButton.hidden = false;
    cancelButton.hidden = false;
    cancelButton.autofocus = true;
    openButton.addEventListener('click', () => dialog.showModal());
    cancelButton.addEventListener('click', () => dialog.close());
    licence.querySelector('a').addEventListener('click', () => dialog.close());
  }
}
