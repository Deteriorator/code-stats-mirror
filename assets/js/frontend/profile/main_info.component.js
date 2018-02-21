import {el, mount, setChildren} from 'redom';
import LoadingIndicatorComponent from '../../common/loading-indicator.component';
import StartupInstructionsComponent from './startup-instructions.component';
import {DateTime} from 'luxon';
import {RECENT_HOURS} from '../config';

import TopLanguagesComponent from './graphs/top-languages.component';
import TopMachinesComponent from './graphs/top-machines.component';

/**
 * MainInfoComponent handles showing either the loading indicator, startup instructions, or list of graphs, and
 * propagates all data updates to those graphs.
 */
class MainInfoComponent {
  constructor(total_xp) {
    this.el = el('div', []);

    this._loading = true;

    // Does user have no data? If so, show startup instructions
    this._noData = total_xp === 0;

    // List of child graphs that should be sent data updates
    this._graphs = [];
  }

  getDataRequest() {
    const now = DateTime.utc();
    const since_recent = now.minus({hours: RECENT_HOURS});

    return {
      total_machines: 'machines {name xp}',
      recent_machines: `machines(since: ${JSON.stringify(since_recent.toISO())}) {name xp}`,
    };
  }

  setInitData(data) {
    console.log('setInitData', data);

    for (const graph of this._graphs) {
      graph.setInitData(data);
    }
  }

  update(data) {
    // Incoming pulse, if startup instructions are shown, replace them with stats list at this point
    if (this._noData) {
      this._noData = false;
      this._showCorrectComponents();
    }

    console.log('update', data);

    for (const graph of this._graphs) {
      graph.update(data);
    }
  }

  setLoadingStatus(status) {
    this._loading = status;

    if (this._loading) {
      setChildren(this.el, [new LoadingIndicatorComponent()]);
    }
    else {
      this._showCorrectComponents();
    }
  }

  _getStatsElems() {
    return [
      new TopLanguagesComponent(),
      new TopMachinesComponent(),
    ];
  }

  _showCorrectComponents() {
    if (this._noData) {
      this._graphs = [];
      setChildren(this.el, [new StartupInstructionsComponent()]);
    }
    else {
      this._graphs = this._getStatsElems();
      setChildren(this.el, this._graphs);
    }
  }
}

export default MainInfoComponent;
