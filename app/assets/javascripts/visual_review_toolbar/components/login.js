import { nextView } from '../store';
import { LOGIN, TOKEN_BOX } from './constants';
import { clearNote, postError } from './note';
import { rememberBox, submitButton } from './form_elements';
import { selectRemember, selectToken } from './utils';
import { addForm } from './wrapper';

const labelText = `
  Enter your <a class="gitlab-link" href="https://docs.gitlab.com/ee/user/profile/personal_access_tokens.html">personal access token</a>
`;

const login = `
    <div>
      <label for="${TOKEN_BOX}" class="gitlab-label">${labelText}</label>
      <input class="gitlab-input" type="password" id="${TOKEN_BOX}" name="${TOKEN_BOX}" autocomplete="current-password" aria-required="true">
    </div>
    ${rememberBox()}
    ${submitButton(LOGIN)}
`;

const storeToken = (token, state) => {
  const { localStorage } = window;
  const rememberMe = selectRemember().checked;

  // All the browsers we support have localStorage, so let's silently fail
  // and go on with the rest of the functionality.
  try {
    if (rememberMe) {
      localStorage.setItem('token', token);
    }
  } finally {
    state.token = token;
  }
};

const authorizeUser = state => {
  // Clear any old errors
  clearNote(TOKEN_BOX);

  const token = selectToken().value;

  if (!token) {
    /* eslint-disable-next-line @gitlab/i18n/no-non-i18n-strings */
    postError('Please enter your token.', TOKEN_BOX);
    return;
  }

  storeToken(token, state);
  addForm(nextView(state, LOGIN));
};

export { authorizeUser, login, storeToken };
