<template>
    <div class="page-container">
        <div class="page-title">Accounts Management</div>
        <div class="toolbar">
            <el-input v-model="query" class="search" placeholder="Search name, email, or role" clearable />
            <span class="count">{{ visibleAccounts.length }} of {{ accounts.length }} accounts</span>
            <span class="spacer"></span>
            <el-button type="primary" @click="addDialogVisible = true">Add accounts</el-button>
        </div>
        <el-table style="width: 100%" :data="visibleAccounts" :default-sort="{ prop: 'created_at', order: 'descending' }">
            <el-table-column type="index" width="50" />
            <el-table-column width="70">
                <template #default="scope">
                    <el-avatar shape="square" :size="40" :src="scope.row.avatar" />
                </template>
            </el-table-column>
            <el-table-column prop="name" label="Name" width="200" sortable>
                <template #default="scope">
                    <el-link type="primary" :underline="false" @click="openDetail(scope.row)">
                        {{ scope.row.name || 'Not logged in yet' }}
                    </el-link>
                    <el-tag v-if="isSelf(scope.row)" size="small" type="success" class="role-tag">you</el-tag>
                </template>
            </el-table-column>
            <el-table-column prop="email" label="Email" sortable />
            <el-table-column prop="roles" label="Roles" sortable :sort-method="compareByRoles">
                <template #default="scope">
                    <el-tag v-for="role in scope.row.roles" :key="role" :type="roleTagType(role)" size="small"
                        class="role-tag">{{ roleLabel(role) }}</el-tag>
                </template>
            </el-table-column>
            <el-table-column prop="created_at" label="Added on" width="130" sortable>
                <template #default="scope">{{ addedOn(scope.row) }}</template>
            </el-table-column>
            <el-table-column label="Operations" width="180">
                <template #default="scope">
                    <el-button @click="openEditDialog(scope.row)" size="small">Edit</el-button>
                    <el-tooltip :disabled="!isSelf(scope.row)" content="You cannot delete your own account" placement="top">
                        <span>
                            <el-button type="danger" :disabled="isSelf(scope.row)" @click="openDeleteDialog(scope.row)"
                                size="small">Delete</el-button>
                        </span>
                    </el-tooltip>
                </template>
            </el-table-column>
        </el-table>

        <AddAccountsDialog v-model="addDialogVisible" @done="getUserRole" />
        <AccountDetailDialog v-model="detailDialogVisible" :account-id="detailAccountId" />
        <DeleteAccountDialog v-if="accountToDelete" v-model="deleteDialogVisible" :account="accountToDelete"
            :enrollment-count="deleteEnrollmentCount" :deleting="deleting" @confirm="deleteAccount" />

        <el-dialog title="Edit Account" v-model="editDialogVisible" width="100%" style="max-width: 600px;">
            <el-form :model="selectedAccount" label-width="80px">
                <el-form-item label="Name">
                    <el-input class="editor-input-box" v-model="selectedAccount.name" autocomplete="off"></el-input>
                </el-form-item>
                <el-form-item label="Email">
                    <el-input class="editor-input-box" v-model="selectedAccount.email" autocomplete="off"></el-input>
                </el-form-item>
                <el-form-item label="Roles">
                    <el-select class="editor-input-box" v-model="selectedAccount.roles" placeholder="Please select a role"
                        multiple>
                        <el-option v-for="option in roleOptions" :key="option.value" :label="option.label"
                            :value="option.value">
                        </el-option>
                    </el-select>
                </el-form-item>
            </el-form>
            <template #footer>
                <el-button @click="editDialogVisible = false">Cancel</el-button>
                <el-button type="primary" @click="confirmEdit">Confirm</el-button>
            </template>
        </el-dialog>
    </div>
</template>


<script>
import api from '@/lib/tytoApi'
import session from '@/lib/session'
import { roleOptions, roleLabel } from '@/lib/roles'
import { filterAccounts, compareByRoles } from '@/lib/accountsTable'
import AddAccountsDialog from './account/components/AddAccountsDialog.vue'
import AccountDetailDialog from './account/components/AccountDetailDialog.vue'
import DeleteAccountDialog from './account/components/DeleteAccountDialog.vue'

const ROLE_TAG_TYPES = { admin: 'danger', creator: 'warning', member: 'info' }

export default {
    components: { AddAccountsDialog, AccountDetailDialog, DeleteAccountDialog },
    data() {
        return {
            user_id: '',
            accounts: [],
            query: '',
            roleOptions,
            addDialogVisible: false,
            editDialogVisible: false,
            selectedAccount: {},
            detailDialogVisible: false,
            detailAccountId: null,
            deleteDialogVisible: false,
            accountToDelete: null,
            deleteEnrollmentCount: null,
            deleting: false
        };
    },
    computed: {
        visibleAccounts() {
            return filterAccounts(this.accounts, this.query)
        }
    },
    mounted() {
        this.user_id = String(session.getAccount()?.id ?? '')
        this.getUserRole();
    },
    methods: {
        roleLabel,
        compareByRoles,
        roleTagType(role) {
            return ROLE_TAG_TYPES[role] || 'info'
        },
        addedOn(account) {
            return account.created_at ? account.created_at.slice(0, 10) : ''
        },
        isSelf(account) {
            return String(account.id) === this.user_id
        },
        openDetail(account) {
            this.detailAccountId = account.id
            this.detailDialogVisible = true
        },
        openEditDialog(account) {
            // Copy so a cancelled edit leaves the row untouched; the table is
            // refetched from the API after a confirmed update.
            this.selectedAccount = JSON.parse(JSON.stringify(account));
            this.editDialogVisible = true;
        },
        confirmEdit() {
            this.updateAccount(this.selectedAccount);
            this.editDialogVisible = false;
        },
        async updateAccount(account) {
            try {
                const payload = { name: account.name, email: account.email, roles: account.roles }
                const response = await api.put(`/account/${account.id}`, payload);
                if (response.status === 200) {
                    this.getUserRole();
                }
            }
            catch (error) {
                console.error('Error updating account', error);
            }
        },
        async openDeleteDialog(account) {
            this.accountToDelete = account
            this.deleteEnrollmentCount = null
            this.deleteDialogVisible = true
            try {
                const { data } = await api.get(`/account/${account.id}`)
                this.deleteEnrollmentCount = data.data.enrollments.length
            }
            catch (error) {
                console.error('Error loading enrollments', error);
            }
        },
        async deleteAccount(account) {
            this.deleting = true
            try {
                const response = await api.delete(`/account/${account.id}`);
                if (response.status === 200) {
                    this.deleteDialogVisible = false
                    this.accountToDelete = null
                    this.getUserRole();
                }
            }
            catch (error) {
                console.error('Error deleting account', error);
            }
            finally {
                this.deleting = false
            }
        },
        async getUserRole() {
            try {
                const response = await api.get('/account');
                if (response.status === 200) {
                    this.accounts = response.data.data;
                }
                else {
                    console.error('Error sending token to backend');
                }
            }
            catch (error) {
                console.error('Error fetching accounts', error);
            }
        },
    }
}
</script>


<style scoped>
.page-container {
    width: 80%;
    margin: auto;
}

.editor-input-box {
    width: 100%;
}

.toolbar {
    display: flex;
    align-items: center;
    gap: 12px;
    flex-wrap: wrap;
    margin-bottom: 12px;
}

.search {
    width: 280px;
    max-width: 100%;
}

.count {
    color: var(--el-text-color-secondary);
    font-size: 13px;
}

.spacer {
    flex: 1;
}

.role-tag {
    margin-right: 4px;
}
</style>
