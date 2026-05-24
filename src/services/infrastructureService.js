import { supabase } from '../supabaseClient';
import { toCamelCase, toSnakeCase } from '../utils/caseConverter';

const DEPARTMENTS_COLLECTION = 'departments';
const ROOMS_COLLECTION = 'rooms';

const toTitleCase = (str) => {
    if (!str || typeof str !== 'string') return str || '';
    return str
        .trim()
        .split(/\s+/)
        .map(word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
        .join(' ');
};

export const departmentService = {
    async getAllDepartments() {
        const { data, error } = await supabase
            .from(DEPARTMENTS_COLLECTION)
            .select('*')
            .order('name', { ascending: true });
        
        if (error) throw error;
        return toCamelCase(data);
    },

    async addDepartment(name, description) {
        const { data, error } = await supabase
            .from(DEPARTMENTS_COLLECTION)
            .insert([{ name: toTitleCase(name), description }])
            .select()
            .single();
            
        if (error) throw error;
        return data.id;
    },

    async updateDepartment(id, data) {
        const { error } = await supabase
            .from(DEPARTMENTS_COLLECTION)
            .update(toSnakeCase(data))
            .eq('id', id);
            
        if (error) throw error;
        return true;
    },

    async deleteDepartment(id) {
        const { error } = await supabase
            .from(DEPARTMENTS_COLLECTION)
            .delete()
            .eq('id', id);
            
        if (error) throw error;
        return true;
    }
};

export const roomService = {
    async getAllRooms() {
        const { data, error } = await supabase
            .from(ROOMS_COLLECTION)
            .select('*')
            .order('name', { ascending: true });
            
        if (error) throw error;
        return toCamelCase(data);
    },

    async addRoom(data) {
        // data should include name, departmentId, type (Ward, Private, ICU), capacity
        const { data: newRoom, error } = await supabase
            .from(ROOMS_COLLECTION)
            .insert([toSnakeCase({
                ...data,
                name: toTitleCase(data.name),
                occupiedBeds: 0
            })])
            .select()
            .single();
            
        if (error) throw error;
        return newRoom.id;
    },

    async updateRoom(id, data) {
        const { error } = await supabase
            .from(ROOMS_COLLECTION)
            .update(toSnakeCase(data))
            .eq('id', id);
            
        if (error) throw error;
        return true;
    },

    async deleteRoom(id) {
        const { error } = await supabase
            .from(ROOMS_COLLECTION)
            .delete()
            .eq('id', id);
            
        if (error) throw error;
        return true;
    }
};
