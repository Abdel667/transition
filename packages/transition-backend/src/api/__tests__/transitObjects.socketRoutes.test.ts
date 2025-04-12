/*
 * Copyright 2024, Polytechnique Montreal and contributors
 *
 * This file is licensed under the MIT License.
 * License text available at https://opensource.org/licenses/MIT
 */
import { v4 as uuidV4 } from 'uuid';
import { EventEmitter } from 'events';
import * as Status from 'chaire-lib-common/lib/utils/Status';
import transitObjectRoutes from '../transitObjects.socketRoutes';
import { duplicateServices } from '../../services/transitObjects/transitServices/ServiceDuplicator';
import { updateSchedulesBatch } from '../../services/transitObjects/TransitObjectsDataHandler';

const socketStub = new EventEmitter();
transitObjectRoutes(socketStub);
jest.mock('../../services/transitObjects/transitServices/ServiceDuplicator', () => {
    return {
        duplicateServices: jest.fn(),
    };
});
const mockedDuplicateAndSave = duplicateServices as jest.MockedFunction<typeof duplicateServices>;
jest.mock('../../services/transitObjects/TransitObjectsDataHandler', () => {
    return {
        updateSchedulesBatch: jest.fn(),
    };
});
const mockedUpdateBatch = updateSchedulesBatch as jest.MockedFunction<typeof updateSchedulesBatch>;

beforeEach(() => {
    jest.clearAllMocks();
});

describe('Service duplication route', () => {
    test('Duplicate with default options', (done) => {
        const originalServices = [uuidV4(), uuidV4()];
        const savedServices = {
            [originalServices[0]]: uuidV4(), 
            [originalServices[1]]: uuidV4()
        };
        mockedDuplicateAndSave.mockResolvedValueOnce(Status.createOk(savedServices));

        socketStub.emit('transitServices.duplicate', originalServices, {}, (status) => {
            expect(Status.isStatusOk(status)).toEqual(true);
            expect(Status.unwrap(status)).toEqual(savedServices);
            expect(mockedDuplicateAndSave).toHaveBeenLastCalledWith(originalServices, {});
            done();
        });
    });

    test('Duplicate with options', (done) => {
        const originalServices = [uuidV4(), uuidV4()];
        const savedServices = {
            [originalServices[0]]: uuidV4(), 
            [originalServices[1]]: uuidV4()
        };
        const options = { newServiceSuffix: ' copy'}
        mockedDuplicateAndSave.mockResolvedValueOnce(Status.createOk(savedServices));

        socketStub.emit('transitServices.duplicate', originalServices, options, (status) => {
            expect(Status.isStatusOk(status)).toEqual(true);
            expect(Status.unwrap(status)).toEqual(savedServices);
            expect(mockedDuplicateAndSave).toHaveBeenLastCalledWith(originalServices, options);
            done();
        });
    });

    test('Duplicate where error occurred', (done) => {
        const originalServices = [uuidV4(), uuidV4()];
        mockedDuplicateAndSave.mockResolvedValueOnce(Status.createError('An error occurred'));

        socketStub.emit('transitServices.duplicate', originalServices, {}, (status) => {
            expect(Status.isStatusOk(status)).toEqual(false);
            expect(Status.isStatusError(status)).toEqual(true);
            expect(mockedDuplicateAndSave).toHaveBeenLastCalledWith(originalServices, {});
            done();
        });
    });
});

describe('Schedules update batch route', () => {

    test('updateSchedulesBatch with default options', (done) => {
        
        const originalSchedules = [uuidV4(), uuidV4()];
        const savedSchedules = [Math.floor(Math.random() * 100), Math.floor(Math.random() * 100)];

        mockedUpdateBatch.mockResolvedValueOnce(Status.createOk(savedSchedules));
        console.log('mockedUpdateBatch', mockedUpdateBatch);
        socketStub.emit('transitSchedule.updateBatch', originalSchedules, (status) => {
            expect(Status.isStatusOk(status)).toEqual(true);
            expect(Status.unwrap(status)).toEqual(savedSchedules);
            expect(mockedUpdateBatch).toHaveBeenCalledWith(originalSchedules);

            done();
        });
    });

    test('updateSchedulesBatch where error occurred', (done) => {
        const originalSchedules = [uuidV4(), uuidV4()];
        mockedDuplicateAndSave.mockResolvedValueOnce(Status.createError('An error occurred'));

        socketStub.emit('transitServices.duplicate', originalSchedules, {}, (status) => {
            expect(Status.isStatusOk(status)).toEqual(false);
            expect(Status.isStatusError(status)).toEqual(true);
            expect(mockedDuplicateAndSave).toHaveBeenLastCalledWith(originalSchedules, {});
            done();
        });
    });

    
});
