/*
 * Copyright 2022-2025, Polytechnique Montreal and contributors
 *
 * This file is licensed under the MIT License.
 * License text available at https://opensource.org/licenses/MIT
 */
import React from 'react';
import { withTranslation, WithTranslation } from 'react-i18next';
import serviceLocator from 'chaire-lib-common/lib/utils/ServiceLocator';
import Line from 'transition-common/lib/services/line/Line';
import Button from '../../parts/Button';
import ButtonCell from '../../parts/ButtonCell';
import { InputCheckboxBoolean } from 'chaire-lib-frontend/lib/components/input/InputCheckbox';
import { EventManager } from 'chaire-lib-common/lib/services/events/EventManager';
import { MapUpdateLayerEventType } from 'chaire-lib-frontend/lib/services/map/events/MapEventsCallbacks';

interface ScheduleBatchButtonProps {
    line: Line;
    selectedLines: Line[];
    lineIsSelected?: boolean;
    //lineIsFocused?: boolean;
    onLineSelectedUpdate: (line: Line, value: boolean) => void;
}

const TransitScheduleBatchButton: React.FunctionComponent<ScheduleBatchButtonProps & WithTranslation> = (props: ScheduleBatchButtonProps & WithTranslation) => {
    //let lineIsSelected = (props.selectedLines && props.selectedLines.some((selectedLine) => selectedLine.getId() === props.line.getId())) || false;

    // const [state, setState] = React.useState<ScheduleBatchButtonProps>({
    //     // lineIsSelected: (props.selectedLines && props.selectedLines.some((selectedLine) => selectedLine.getId() === props.line.getId())) || false;
    //     lineIsSelected: (props.selectedLines && props.selectedLines.some((selectedLine) => selectedLine.getId() === props.line.getId())) || false,
    //     //lineIsFocused: (props.focusedLine && props.focusedLine.getId() === props.line.getId()) || false
    // });

    let lineIsSelected = (props.selectedLines && props.selectedLines.some((selectedLine) => selectedLine.getId() === props.line.getId())) || false;
    const lineId = props.line.getId()

    const onClick = () => {
        props.onLineSelectedUpdate(props.line, !lineIsSelected)
        //setState({lineIsSelected: !state.lineIsSelected, lineIsFocused: true})
    }

    const onCheckboxChange = (value) => {
    }

    const pathsCount = props.line.paths.length;
    const scheduledServicesCount =
        props.line.attributes.service_ids !== undefined
            ? props.line.attributes.service_ids.length
            : Object.keys(props.line.attributes.scheduleByServiceId).length;

    return (
        <Button
            key={props.line.getId()}
            isSelected={lineIsSelected}
            flushActionButtons={false}
            onSelect={{ handler: onClick }}
        >
            <InputCheckboxBoolean
                id={`transitBatchLineSelect${lineId}`}
                label=" "
                isChecked={lineIsSelected}
                onValueChange={ (e) => onCheckboxChange(e.target.value) }
            />

            <ButtonCell alignment="left">
                <span className="_circle-button" style={{ backgroundColor: props.line.attributes.color }}></span>
                <img
                    className="_list-element _icon-alone"
                    src={`/dist/images/icons/transit/modes/${props.line.getAttributes().mode}_white.svg`}
                    alt={props.t(`transit:transitLine:modes:${props.line.getAttributes().mode}`)}
                    title={props.t(`transit:transitLine:modes:${props.line.getAttributes().mode}`)}
                />
            </ButtonCell>

            <ButtonCell alignment="left">{props.line.attributes.shortname}</ButtonCell>
            <ButtonCell alignment="left">{props.line.attributes.longname}</ButtonCell>
            <ButtonCell alignment="flush">
                {pathsCount > 1
                    ? props.t('transit:transitLine:nPaths', { n: pathsCount })
                    : props.t('transit:transitLine:nPath', { n: pathsCount })}{' '}
                {scheduledServicesCount > 0 && (
                    <span className="_list-element">
                        {scheduledServicesCount > 1
                            ? props.t('transit:transitLine:nServices', { n: scheduledServicesCount })
                            : props.t('transit:transitLine:nService', { n: scheduledServicesCount })}
                    </span>
                )}
            </ButtonCell>
        </Button>
    );
};

export default withTranslation(['transit', 'main', 'notifications'])(TransitScheduleBatchButton);
