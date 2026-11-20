/* Switch between genuine captures. The first capture works without JavaScript. */
const captures = {
  mac: { image: 'home', widths: [800, 1600], width: 2560, height: 1600, alt: 'Ultimate Lemmix Mac Home with the three starter puzzles, Start Journey and import controls.', caption: 'Mac Home. Current Store candidate.' },
  phone: { image: 'phone', widths: [402, 804], width: 1206, height: 2622, alt: 'Ultimate Lemmix iPhone Home with stone controls and the three included starter levels.', caption: 'iPhone Home. Actual simulator capture.' },
  tv: { image: 'tv', widths: [960, 1920], width: 3840, height: 2160, alt: 'Ultimate Lemmix Apple TV Home with the Lemmix logo, journey and import controls.', caption: 'Apple TV Home. Actual simulator capture.' }
};
const gallery = document.querySelector('[data-gallery]');
if (gallery) {
  gallery.querySelector('.capture-tabs').hidden = false;
  for (const button of gallery.querySelectorAll('[data-capture]')) {
    button.addEventListener('click', () => {
      const key = button.dataset.capture;
      const item = captures[key];
      const image = document.querySelector('#platform-image');
      const source = document.querySelector('#platform-webp');
      source.srcset = item.widths.map(width => `/assets/${item.image}-${width}.webp ${width}w`).join(', ');
      image.src = `/assets/${item.image}-${item.widths.at(-1)}.jpg`;
      image.width = item.width;
      image.height = item.height;
      image.alt = item.alt;
      gallery.dataset.active = key;
      document.querySelector('#platform-caption').textContent = item.caption;
      for (const other of gallery.querySelectorAll('[data-capture]')) other.setAttribute('aria-pressed', String(other === button));
    });
  }
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
