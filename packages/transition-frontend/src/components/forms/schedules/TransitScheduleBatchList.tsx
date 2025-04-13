/*
 * Copyright 2022-2025, Polytechnique Montreal and contributors
 *
 * This file is licensed under the MIT License.
 * License text available at https://opensource.org/licenses/MIT
 */
import React from 'react';
import { withTranslation, WithTranslation } from 'react-i18next';
import { faWindowClose } from '@fortawesome/free-solid-svg-icons/faWindowClose';

import Button from 'chaire-lib-frontend/lib/components/input/Button';
import Path from 'transition-common/lib/services/path/Path';
import serviceLocator from 'chaire-lib-common/lib/utils/ServiceLocator';
import Line from 'transition-common/lib/services/line/Line';
import TransitScheduleBatchButton from './TransitScheduleBatchButton';
import ButtonList from '../../parts/ButtonList';

interface BatchLineSelectProps extends WithTranslation {
    batchSelectedLines?: Map<String, [Path, Path]>;
    selectedLine: Line;
    //onObjectSelected?: (objectId: string) => void;
}

const TransitScheduleBatchLineSelect: React.FunctionComponent<BatchLineSelectProps> = (props: BatchLineSelectProps) => {

    const [state, setState] = React.useState<BatchLineSelectProps>({
        batchSelectedLines: serviceLocator.selectedObjectsManager.getSingleSelection('scheduleBatchLines'),
        selectedLine: serviceLocator.selectedObjectsManager.getSingleSelection('line') && serviceLocator.selectedObjectsManager.getSingleSelection('line')[0]
    });
    const agencyCollection = serviceLocator.collectionManager.get('agencies').getFeatures()

    React.useEffect(() => {
        const onBatchSelectedLinesUpdate = () =>
            /* eslint-disable-next-line @typescript-eslint/no-unused-vars */
            setState(({ batchSelectedLines, ...rest }) => ({
                ...rest,
                batchSelectedLines: serviceLocator.selectedObjectsManager.getSingleSelection('scheduleBatchLines')
            }));
        serviceLocator.eventManager.on('selected.update.scheduleBatchLines', onBatchSelectedLinesUpdate);
        return () => {
            serviceLocator.eventManager.off('selected.update.scheduleBatchLines', onBatchSelectedLinesUpdate);
        };
    }, []);

    const onLineSelectedUpdate = (selectedLine) => {
        setState({selectedLine: selectedLine})
        serviceLocator.selectedObjectsManager.setSelection('line', [state.selectedLine])
    }


    let linesButtons: any[] = [];

    agencyCollection.forEach(agency => {
        const agencyLinesButtons: any[] = []
        agency.getLines().forEach(line => {
            if (line.getOutboundPaths().length > 0 && line.getInboundPaths().length > 0)
                agencyLinesButtons.push(<TransitScheduleBatchButton key={line.id} line={line} selectedLine={state.selectedLine} onLineSelected={onLineSelectedUpdate}/>)
        });

        if (agencyLinesButtons.length > 0)
            linesButtons.push(<h4 key={agency.getId()} alignment="left">{agency.toString()}</h4>)
        linesButtons = linesButtons.concat(agencyLinesButtons)
    });

    return (
        <div>
            <h3>
                <img
                    src={'/dist/images/icons/transit/schedule_white.svg'}
                    className="_icon"
                    alt={props.t('transit:transitSchedule:BatchSchedules')}
                />{' '}
                {props.t('transit:transitSchedule:BatchSchedules')}

            </h3>

            <ButtonList>{linesButtons}</ButtonList>

            {!props.batchSelectedLines && (
                <Button
                    color="grey"
                    icon={faWindowClose}
                    iconClass="_icon"
                    label={props.t('transit:transitSchedule:CloseSchedulesWindow')}
                    onClick={function () {
                        // close
                        serviceLocator.selectedObjectsManager.setSelection('scheduleMode', []);
                        serviceLocator.eventManager.emit('fullSizePanel.hide');
                    }}
                />
            )}
        </div>
    );
};

export default withTranslation('transit')(TransitScheduleBatchLineSelect);
