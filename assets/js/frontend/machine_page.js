import {wait_for_load} from '../common/utils';

/**
 * Code to execute on machines page. Adds prompt for deleting machines.
 */

async function machine_page() {
  await wait_for_load();

  const delete_buttons = document.getElementsByClassName('machine-delete-button');

  for (const button of delete_buttons) {
    button.onclick = () => {
      return confirm('Are you sure you wish to delete this machine? You will lose all XP associated with it.');
    };
  }

  const deactivate_buttons = document.getElementsByClassName('machine-deactivate-button');

  for (const button of deactivate_buttons) {
    button.onclick = () => confirm('Are you sure you wish to deactivate this machine? It will be hidden, but can be re-activated.');
  }

  const regenerate_buttons = document.getElementsByClassName('machine-regenerate-button');

  for (const button of regenerate_buttons) {
    button.onclick = () => confirm('Are you sure you wish to regenerate the API key? The old API key will stop functioning immediately.');
  }

  const copy_buttons = document.getElementsByClassName('copy-button');

  for (const button of copy_buttons) {
    button.onclick = () => {
      button.parentElement.getElementsByClassName('api-key')[0].select();
      try {
        document.execCommand('copy');
        button.textContent = 'Copied!';
      }
      catch (e) {
        button.textContent = 'Error';
      }
    };
  }
}

export default machine_page;
