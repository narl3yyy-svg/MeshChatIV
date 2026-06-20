<template>
    <div class="flex flex-col flex-1 overflow-hidden min-w-0 bg-slate-50 dark:bg-zinc-950">
        <ToolsPageHeader
            icon="file-multiple"
            :title="$t('files.title')"
            :description="$t('files.description')"
            :eyebrow="$t('files.file_sharing')"
            accent="indigo"
        />
        <div
            class="flex-1 overflow-y-auto w-full px-4 md:px-5 lg:px-8 py-6 pb-[max(1.5rem,env(safe-area-inset-bottom))]"
        >
            <div class="space-y-4 w-full max-w-4xl mx-auto">
                <div class="glass-card space-y-5">
                    <div class="flex items-center justify-between">
                        <div
                            class="border-b border-gray-200 dark:border-zinc-700 overflow-x-auto overscroll-x-contain -mx-4 px-4 sm:mx-0 sm:px-0 flex-1"
                        >
                            <div class="flex w-max min-w-full sm:w-auto gap-1 sm:gap-2">
                                <button
                                    type="button"
                                    :class="[
                                        activeTab === 'send'
                                            ? 'border-b-2 border-indigo-500 text-indigo-600 dark:text-indigo-400'
                                            : 'text-gray-600 dark:text-gray-400',
                                        'shrink-0 px-3 sm:px-4 py-2 text-sm font-semibold transition',
                                    ]"
                                    @click="activeTab = 'send'"
                                >
                                    <MaterialDesignIcon icon-name="upload" class="w-4 h-4 inline-block mr-1" />
                                    {{ $t("files.send") }}
                                </button>
                                <button
                                    type="button"
                                    :class="[
                                        activeTab === 'receive'
                                            ? 'border-b-2 border-indigo-500 text-indigo-600 dark:text-indigo-400'
                                            : 'text-gray-600 dark:text-gray-400',
                                        'shrink-0 px-3 sm:px-4 py-2 text-sm font-semibold transition',
                                    ]"
                                    @click="activeTab = 'receive'"
                                >
                                    <MaterialDesignIcon icon-name="download" class="w-4 h-4 inline-block mr-1" />
                                    {{ $t("files.receive") }}
                                </button>
                                <button
                                    type="button"
                                    :class="[
                                        activeTab === 'browse'
                                            ? 'border-b-2 border-indigo-500 text-indigo-600 dark:text-indigo-400'
                                            : 'text-gray-600 dark:text-gray-400',
                                        'shrink-0 px-3 sm:px-4 py-2 text-sm font-semibold transition',
                                    ]"
                                    @click="activeTab = 'browse'; refreshFiles()"
                                >
                                    <MaterialDesignIcon icon-name="folder" class="w-4 h-4 inline-block mr-1" />
                                    {{ $t("files.browse") }}
                                </button>
                                <button
                                    type="button"
                                    :class="[
                                        activeTab === 'listen'
                                            ? 'border-b-2 border-indigo-500 text-indigo-600 dark:text-indigo-400'
                                            : 'text-gray-600 dark:text-gray-400',
                                        'shrink-0 px-3 sm:px-4 py-2 text-sm font-semibold transition',
                                    ]"
                                    @click="activeTab = 'listen'; refreshListenerStatus()"
                                >
                                    <MaterialDesignIcon icon-name="ear-hearing" class="w-4 h-4 inline-block mr-1" />
                                    {{ $t("files.listen") }}
                                </button>
                                <button
                                    type="button"
                                    :class="[
                                        activeTab === 'history'
                                            ? 'border-b-2 border-indigo-500 text-indigo-600 dark:text-indigo-400'
                                            : 'text-gray-600 dark:text-gray-400',
                                        'shrink-0 px-3 sm:px-4 py-2 text-sm font-semibold transition',
                                    ]"
                                    @click="activeTab = 'history'; refreshHistory()"
                                >
                                    <MaterialDesignIcon icon-name="history" class="w-4 h-4 inline-block mr-1" />
                                    {{ $t("files.history") }}
                                </button>
                            </div>
                        </div>
                    </div>

                    <div v-if="activeTab === 'send'" class="space-y-4">
                        <div class="grid lg:grid-cols-2 gap-4">
                            <div class="relative">
                                <label class="glass-label">{{ $t("files.destination_hash") }}</label>
                                <div class="relative">
                                    <input
                                        v-model="sendDestinationHash"
                                        type="text"
                                        placeholder="e.g. 7b746057a7294469799cd8d7d429676a"
                                        class="input-field font-mono pr-8"
                                        @focus="showSendContactPicker = true; fetchContacts()"
                                        @blur="setTimeout(() => showSendContactPicker = false, 200)"
                                        @input="fetchContacts(sendDestinationHash)"
                                    />
                                    <MaterialDesignIcon
                                        icon-name="account-multiple"
                                        class="w-4 h-4 absolute right-2.5 top-1/2 -translate-y-1/2 text-gray-400 dark:text-zinc-500 cursor-pointer hover:text-indigo-500 transition-colors"
                                        @mousedown.prevent="showSendContactPicker = !showSendContactPicker; if (showSendContactPicker) fetchContacts()"
                                    />
                                </div>
                                <div
                                    v-if="showSendContactPicker"
                                    class="absolute z-50 left-0 right-0 mt-1 max-h-64 overflow-y-auto rounded-lg bg-white dark:bg-zinc-800 border border-gray-200 dark:border-zinc-700 shadow-lg"
                                >
                                    <div
                                        v-if="contacts.length === 0"
                                        class="text-sm text-gray-500 dark:text-zinc-400 text-center py-3 px-3"
                                    >
                                        {{ $t("files.no_contacts_found") }}
                                    </div>
                                    <button
                                        v-for="c in contacts"
                                        :key="c.id || c.remote_identity_hash"
                                        type="button"
                                        class="w-full text-left px-3 py-2 text-sm hover:bg-gray-100 dark:hover:bg-zinc-700/50 transition border-b border-gray-100 dark:border-zinc-700/50 last:border-0"
                                        @mousedown.prevent="selectSendContact(c)"
                                    >
                                        <div class="font-medium text-gray-800 dark:text-zinc-200 truncate mb-1">
                                            {{ c.name || $t("files.unnamed_contact") }}
                                        </div>
                                        <div v-if="c.remote_identity_hash" class="flex items-center gap-1 text-xs">
                                            <span class="shrink-0 px-1 py-0.5 rounded bg-indigo-100 dark:bg-indigo-900/40 text-indigo-700 dark:text-indigo-300 font-mono font-semibold">RNS</span>
                                            <span class="text-gray-500 dark:text-zinc-400 font-mono truncate">{{ c.remote_identity_hash }}</span>
                                        </div>
                                        <div v-if="c.lxmf_address && c.lxmf_address !== c.remote_identity_hash" class="flex items-center gap-1 text-xs mt-0.5">
                                            <span class="shrink-0 px-1 py-0.5 rounded bg-amber-100 dark:bg-amber-900/40 text-amber-700 dark:text-amber-300 font-mono font-semibold">LXMF</span>
                                            <span class="text-gray-500 dark:text-zinc-400 font-mono truncate">{{ c.lxmf_address }}</span>
                                        </div>
                                    </button>
                                </div>
                            </div>
                            <div>
                                <label class="glass-label">{{ $t("files.description") }}</label>
                                <input
                                    v-model="sendDescription"
                                    type="text"
                                    :placeholder="$t('files.description_placeholder')"
                                    class="input-field"
                                />
                            </div>
                        </div>
                        <div class="grid lg:grid-cols-2 gap-4">
                            <div>
                                <label class="glass-label">{{ $t("files.file_path") }}</label>
                                <div class="flex gap-2">
                                    <input
                                        v-model="sendFilePath"
                                        type="text"
                                        placeholder="/path/to/file"
                                        class="input-field flex-1 min-w-0"
                                    />
                                    <input
                                        ref="sendFileInput"
                                        type="file"
                                        class="hidden"
                                        @change="onWebSendFilePicked"
                                    />
                                    <button
                                        type="button"
                                        class="secondary-chip px-3 py-2 text-xs shrink-0"
                                        :title="$t('files.browse_file')"
                                        @click="pickSendFile"
                                    >
                                        <MaterialDesignIcon icon-name="folder-open-outline" class="w-4 h-4" />
                                    </button>
                                </div>
                            </div>
                            <div>
                                <label class="glass-label">{{ $t("files.timeout_seconds") }}</label>
                                <input v-model="sendTimeout" type="number" min="1" class="input-field" />
                            </div>
                        </div>
                        <div class="flex gap-2">
                            <button
                                v-if="!sendInProgress"
                                type="button"
                                class="primary-chip px-4 py-2 text-sm"
                                @click="sendFile"
                            >
                                <MaterialDesignIcon icon-name="upload" class="w-4 h-4" />
                                {{ $t("files.send_file") }}
                            </button>
                            <button
                                v-else
                                type="button"
                                class="secondary-chip px-4 py-2 text-sm text-red-600 dark:text-red-300 border-red-200 dark:border-red-500/50"
                                @click="cancelSend"
                            >
                                <MaterialDesignIcon icon-name="close" class="w-4 h-4" />
                                {{ $t("files.cancel") }}
                            </button>
                        </div>
                        <div v-if="sendProgress > 0" class="space-y-2">
                            <div class="flex justify-between text-sm">
                                <span class="text-gray-700 dark:text-gray-300">{{ $t("files.progress") }}</span>
                                <span class="text-gray-700 dark:text-gray-300">{{ Math.round(sendProgress * 100) }}%</span>
                            </div>
                            <div class="w-full bg-gray-200 dark:bg-zinc-700 rounded-full h-2">
                                <div
                                    class="bg-indigo-600 h-2 rounded-full transition-all"
                                    :style="{ width: sendProgress * 100 + '%' }"
                                ></div>
                            </div>
                        </div>
                        <div
                            v-if="sendResult"
                            class="p-3 rounded-lg space-y-2"
                            :class="sendResult.success
                                ? 'bg-green-50 dark:bg-green-900/20 text-green-700 dark:text-green-300'
                                : 'bg-red-50 dark:bg-red-900/20 text-red-700 dark:text-red-300'"
                        >
                            <div>{{ sendResult.message }}</div>
                            <div v-if="sendResult.success && sendResult.details" class="text-xs break-all">
                                {{ sendResult.details }}
                            </div>
                        </div>
                    </div>

                    <div v-if="activeTab === 'receive'" class="space-y-4">
                        <div class="grid lg:grid-cols-2 gap-4">
                            <div class="relative">
                                <label class="glass-label">{{ $t("files.peer_hash") }}</label>
                                <div class="relative">
                                    <input
                                        v-model="fetchDestinationHash"
                                        type="text"
                                        placeholder="e.g. 7b746057a7294469799cd8d7d429676a"
                                        class="input-field font-mono pr-8"
                                        @focus="showFetchContactPicker = true; fetchContacts()"
                                        @blur="setTimeout(() => showFetchContactPicker = false, 200)"
                                        @input="fetchContacts(fetchDestinationHash)"
                                    />
                                    <MaterialDesignIcon
                                        icon-name="account-multiple"
                                        class="w-4 h-4 absolute right-2.5 top-1/2 -translate-y-1/2 text-gray-400 dark:text-zinc-500 cursor-pointer hover:text-indigo-500 transition-colors"
                                        @mousedown.prevent="showFetchContactPicker = !showFetchContactPicker; if (showFetchContactPicker) fetchContacts()"
                                    />
                                </div>
                                <div
                                    v-if="showFetchContactPicker"
                                    class="absolute z-50 left-0 right-0 mt-1 max-h-64 overflow-y-auto rounded-lg bg-white dark:bg-zinc-800 border border-gray-200 dark:border-zinc-700 shadow-lg"
                                >
                                    <div
                                        v-if="contacts.length === 0"
                                        class="text-sm text-gray-500 dark:text-zinc-400 text-center py-3 px-3"
                                    >
                                        {{ $t("files.no_contacts_found") }}
                                    </div>
                                    <button
                                        v-for="c in contacts"
                                        :key="c.id || c.remote_identity_hash"
                                        type="button"
                                        class="w-full text-left px-3 py-2 text-sm hover:bg-gray-100 dark:hover:bg-zinc-700/50 transition border-b border-gray-100 dark:border-zinc-700/50 last:border-0"
                                        @mousedown.prevent="selectFetchContact(c)"
                                    >
                                        <div class="font-medium text-gray-800 dark:text-zinc-200 truncate mb-1">
                                            {{ c.name || $t("files.unnamed_contact") }}
                                        </div>
                                        <div v-if="c.remote_identity_hash" class="flex items-center gap-1 text-xs">
                                            <span class="shrink-0 px-1 py-0.5 rounded bg-indigo-100 dark:bg-indigo-900/40 text-indigo-700 dark:text-indigo-300 font-mono font-semibold">RNS</span>
                                            <span class="text-gray-500 dark:text-zinc-400 font-mono truncate">{{ c.remote_identity_hash }}</span>
                                        </div>
                                        <div v-if="c.lxmf_address && c.lxmf_address !== c.remote_identity_hash" class="flex items-center gap-1 text-xs mt-0.5">
                                            <span class="shrink-0 px-1 py-0.5 rounded bg-amber-100 dark:bg-amber-900/40 text-amber-700 dark:text-amber-300 font-mono font-semibold">LXMF</span>
                                            <span class="text-gray-500 dark:text-zinc-400 font-mono truncate">{{ c.lxmf_address }}</span>
                                        </div>
                                    </button>
                                </div>
                            </div>
                            <div>
                                <label class="glass-label">{{ $t("files.remote_path") }}</label>
                                <input
                                    v-model="fetchFilePath"
                                    type="text"
                                    :placeholder="$t('files.remote_path_placeholder')"
                                    class="input-field"
                                />
                            </div>
                        </div>
                        <div class="grid lg:grid-cols-2 gap-4">
                            <div>
                                <label class="glass-label">{{ $t("files.save_path_optional") }}</label>
                                <div class="flex gap-2">
                                    <input
                                        v-model="fetchSavePath"
                                        type="text"
                                        :placeholder="$t('files.save_path_placeholder')"
                                        class="input-field flex-1 min-w-0"
                                    />
                                    <button
                                        type="button"
                                        class="secondary-chip px-3 py-2 text-xs shrink-0"
                                        :title="$t('files.browse_folder')"
                                        @click="pickFetchSaveDirectory"
                                    >
                                        <MaterialDesignIcon icon-name="folder-open-outline" class="w-4 h-4" />
                                    </button>
                                </div>
                            </div>
                            <div>
                                <label class="glass-label">{{ $t("files.timeout_seconds") }}</label>
                                <input v-model="fetchTimeout" type="number" min="1" class="input-field" />
                            </div>
                        </div>
                        <div class="flex items-center gap-4">
                            <label class="flex items-center gap-2 cursor-pointer">
                                <input v-model="fetchAllowOverwrite" type="checkbox" class="rounded-sm" />
                                <span class="text-sm text-gray-700 dark:text-gray-300">{{ $t("files.allow_overwrite") }}</span>
                            </label>
                        </div>
                        <div class="flex gap-2">
                            <button
                                v-if="!fetchInProgress"
                                type="button"
                                class="primary-chip px-4 py-2 text-sm"
                                @click="fetchFile"
                            >
                                <MaterialDesignIcon icon-name="download" class="w-4 h-4" />
                                {{ $t("files.fetch_file") }}
                            </button>
                            <button
                                v-else
                                type="button"
                                class="secondary-chip px-4 py-2 text-sm text-red-600 dark:text-red-300 border-red-200 dark:border-red-500/50"
                                @click="cancelFetch"
                            >
                                <MaterialDesignIcon icon-name="close" class="w-4 h-4" />
                                {{ $t("files.cancel") }}
                            </button>
                        </div>
                        <div v-if="fetchProgress > 0" class="space-y-2">
                            <div class="flex justify-between text-sm">
                                <span class="text-gray-700 dark:text-gray-300">{{ $t("files.progress") }}</span>
                                <span class="text-gray-700 dark:text-gray-300">{{ Math.round(fetchProgress * 100) }}%</span>
                            </div>
                            <div class="w-full bg-gray-200 dark:bg-zinc-700 rounded-full h-2">
                                <div
                                    class="bg-indigo-600 h-2 rounded-full transition-all"
                                    :style="{ width: fetchProgress * 100 + '%' }"
                                ></div>
                            </div>
                        </div>
                        <div
                            v-if="fetchResult"
                            class="p-3 rounded-lg space-y-2"
                            :class="fetchResult.success
                                ? 'bg-green-50 dark:bg-green-900/20 text-green-700 dark:text-green-300'
                                : 'bg-red-50 dark:bg-red-900/20 text-red-700 dark:text-red-300'"
                        >
                            <div>{{ fetchResult.message }}</div>
                            <div v-if="fetchResult.success && fetchResult.details" class="text-xs break-all">
                                {{ fetchResult.details }}
                            </div>
                        </div>
                    </div>

                    <div v-if="activeTab === 'browse'" class="space-y-4">
                        <div class="flex items-center gap-4 mb-4">
                            <div class="flex gap-2">
                                <button
                                    type="button"
                                    :class="browseTab === 'shared'
                                        ? 'bg-indigo-100 dark:bg-indigo-900/30 text-indigo-700 dark:text-indigo-300'
                                        : 'bg-gray-100 dark:bg-zinc-800 text-gray-600 dark:text-gray-400'"
                                    class="px-3 py-1.5 text-sm font-semibold rounded-lg transition"
                                    @click="browseTab = 'shared'; refreshFiles()"
                                >
                                    <MaterialDesignIcon icon-name="folder-upload" class="w-4 h-4 inline mr-1" />
                                    {{ $t("files.shared_files") }}
                                </button>
                                <button
                                    type="button"
                                    :class="browseTab === 'received'
                                        ? 'bg-indigo-100 dark:bg-indigo-900/30 text-indigo-700 dark:text-indigo-300'
                                        : 'bg-gray-100 dark:bg-zinc-800 text-gray-600 dark:text-gray-400'"
                                    class="px-3 py-1.5 text-sm font-semibold rounded-lg transition"
                                    @click="browseTab = 'received'; refreshFiles()"
                                >
                                    <MaterialDesignIcon icon-name="folder-download" class="w-4 h-4 inline mr-1" />
                                    {{ $t("files.received_files") }}
                                </button>
                            </div>
                            <div class="ml-auto">
                                <button
                                    type="button"
                                    class="secondary-chip px-3 py-1.5 text-xs"
                                    @click="refreshFiles"
                                >
                                    <MaterialDesignIcon icon-name="refresh" class="w-4 h-4 inline mr-1" />
                                    {{ $t("files.refresh") }}
                                </button>
                            </div>
                        </div>

                        <div v-if="browseTab === 'shared'" class="space-y-2">
                            <div
                                class="p-3 rounded-lg bg-blue-50/50 dark:bg-blue-900/10 border border-blue-100 dark:border-blue-900/20 mb-3"
                            >
                                <div class="text-xs text-blue-700 dark:text-blue-300">
                                    <MaterialDesignIcon icon-name="information" class="w-4 h-4 inline mr-1" />
                                    {{ $t("files.shared_dir_info") }}
                                </div>
                                <div class="font-mono text-xs text-blue-600 dark:text-blue-400 mt-1 break-all">
                                    {{ storageInfo?.shared_dir || "" }}
                                </div>
                            </div>

                            <div v-if="addFileMode" class="flex gap-2 mb-3">
                                <input
                                    v-model="addFilePath"
                                    type="text"
                                    :placeholder="$t('files.add_file_placeholder')"
                                    class="input-field flex-1 min-w-0"
                                />
                                <input
                                    ref="addFileInput"
                                    type="file"
                                    class="hidden"
                                    @change="onWebAddFilePicked"
                                />
                                <button
                                    type="button"
                                    class="secondary-chip px-3 py-2 text-xs"
                                    @click="pickAddFile"
                                >
                                    <MaterialDesignIcon icon-name="folder-open-outline" class="w-4 h-4" />
                                </button>
                                <button
                                    type="button"
                                    class="primary-chip px-3 py-2 text-xs"
                                    @click="copyToShared"
                                >
                                    <MaterialDesignIcon icon-name="plus" class="w-4 h-4" />
                                    {{ $t("files.add") }}
                                </button>
                                <button
                                    type="button"
                                    class="secondary-chip px-3 py-2 text-xs"
                                    @click="addFileMode = false; addFilePath = ''"
                                >
                                    <MaterialDesignIcon icon-name="close" class="w-4 h-4" />
                                </button>
                            </div>
                            <button
                                v-else
                                type="button"
                                class="secondary-chip px-3 py-1.5 text-xs mb-3"
                                @click="addFileMode = true"
                            >
                                <MaterialDesignIcon icon-name="plus" class="w-4 h-4 inline mr-1" />
                                {{ $t("files.add_file") }}
                            </button>

                            <div v-if="sharedFiles.length === 0" class="text-sm text-gray-500 dark:text-zinc-400 text-center py-8">
                                <MaterialDesignIcon icon-name="folder-open-outline" class="w-8 h-8 mx-auto mb-2 opacity-50" />
                                {{ $t("files.no_shared_files") }}
                            </div>
                            <div v-else class="space-y-1">
                                <div
                                    v-for="file in sharedFiles"
                                    :key="file.path"
                                    class="flex items-center gap-3 p-2.5 rounded-lg hover:bg-gray-50 dark:hover:bg-zinc-800/50 transition-colors border border-transparent hover:border-gray-200 dark:hover:border-zinc-700"
                                >
                                    <MaterialDesignIcon
                                        :icon-name="getFileIcon(file.name)"
                                        class="w-5 h-5 shrink-0 text-gray-500 dark:text-zinc-400"
                                    />
                                    <div class="min-w-0 flex-1">
                                        <div class="text-sm font-medium text-gray-800 dark:text-zinc-200 truncate" :title="file.name">
                                            {{ file.name }}
                                        </div>
                                        <div class="text-xs text-gray-500 dark:text-zinc-500">
                                            {{ formatFileSize(file.size) }} &middot; {{ formatDate(file.modified) }}
                                        </div>
                                    </div>
                                    <button
                                        type="button"
                                        class="secondary-chip text-xs py-1 px-2 text-red-600 dark:text-red-400 hover:bg-red-50 dark:hover:bg-red-900/20"
                                        :title="$t('files.delete')"
                                        @click="deleteSharedFile(file.name)"
                                    >
                                        <MaterialDesignIcon icon-name="delete-outline" class="w-4 h-4" />
                                    </button>
                                </div>
                            </div>
                        </div>

                        <div v-if="browseTab === 'received'" class="space-y-2">
                            <div
                                class="p-3 rounded-lg bg-blue-50/50 dark:bg-blue-900/10 border border-blue-100 dark:border-blue-900/20 mb-3"
                            >
                                <div class="text-xs text-blue-700 dark:text-blue-300">
                                    <MaterialDesignIcon icon-name="information" class="w-4 h-4 inline mr-1" />
                                    {{ $t("files.received_dir_info") }}
                                </div>
                                <div class="font-mono text-xs text-blue-600 dark:text-blue-400 mt-1 break-all">
                                    {{ storageInfo?.received_dir || "" }}
                                </div>
                            </div>

                            <div v-if="receivedFiles.length === 0" class="text-sm text-gray-500 dark:text-zinc-400 text-center py-8">
                                <MaterialDesignIcon icon-name="folder-download-outline" class="w-8 h-8 mx-auto mb-2 opacity-50" />
                                {{ $t("files.no_received_files") }}
                            </div>
                            <div v-else class="space-y-1">
                                <div
                                    v-for="file in receivedFiles"
                                    :key="file.path"
                                    class="flex items-center gap-3 p-2.5 rounded-lg hover:bg-gray-50 dark:hover:bg-zinc-800/50 transition-colors border border-transparent hover:border-gray-200 dark:hover:border-zinc-700"
                                >
                                    <MaterialDesignIcon
                                        :icon-name="getFileIcon(file.name)"
                                        class="w-5 h-5 shrink-0 text-gray-500 dark:text-zinc-400"
                                    />
                                    <div class="min-w-0 flex-1">
                                        <div class="text-sm font-medium text-gray-800 dark:text-zinc-200 truncate" :title="file.name">
                                            {{ file.name }}
                                        </div>
                                        <div class="text-xs text-gray-500 dark:text-zinc-500">
                                            {{ formatFileSize(file.size) }} &middot; {{ formatDate(file.modified) }}
                                        </div>
                                    </div>
                                    <button
                                        type="button"
                                        class="secondary-chip text-xs py-1 px-2"
                                        @click="openPathInOs(file.path)"
                                    >
                                        <MaterialDesignIcon icon-name="folder-open-outline" class="w-4 h-4" />
                                    </button>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div v-if="activeTab === 'listen'" class="space-y-4">
                        <div class="grid lg:grid-cols-2 gap-4">
                            <div>
                                <label class="glass-label">{{ $t("files.allowed_hashes") }}</label>
                                <textarea
                                    v-model="listenAllowedHashes"
                                    rows="4"
                                    placeholder="7b746057a7294469799cd8d7d429676a&#10;8c857168b830557080ad9e8e8e539787b"
                                    class="input-field font-mono text-sm"
                                ></textarea>
                            </div>
                            <div>
                                <label class="glass-label">{{ $t("files.fetch_jail") }}</label>
                                <input
                                    v-model="listenFetchJail"
                                    type="text"
                                    placeholder="/path/to/jail"
                                    class="input-field"
                                />
                            </div>
                        </div>
                        <div class="flex items-end gap-4">
                            <label class="flex items-center gap-2 cursor-pointer">
                                <input v-model="listenFetchAllowed" type="checkbox" class="rounded-sm" />
                                <span class="text-sm text-gray-700 dark:text-gray-300">{{ $t("files.allow_fetch") }}</span>
                            </label>
                            <label class="flex items-center gap-2 cursor-pointer">
                                <input v-model="listenAllowOverwrite" type="checkbox" class="rounded-sm" />
                                <span class="text-sm text-gray-700 dark:text-gray-300">{{ $t("files.allow_overwrite") }}</span>
                            </label>
                        </div>

                        <div
                            v-if="listenDestinationHash"
                            class="p-3 rounded-lg bg-indigo-50 dark:bg-indigo-900/20 text-indigo-700 dark:text-indigo-300 space-y-2"
                        >
                            <div class="text-sm font-semibold">{{ $t("files.listening_on") }}</div>
                            <div class="font-mono text-xs break-all">{{ listenDestinationHash }}</div>
                        </div>

                        <div
                            v-if="storageInfo"
                            class="p-3 rounded-lg bg-slate-50 dark:bg-zinc-800/80 border border-gray-200 dark:border-zinc-700 space-y-2"
                        >
                            <div class="text-xs font-semibold text-gray-600 dark:text-zinc-300">
                                <MaterialDesignIcon icon-name="harddisk" class="w-4 h-4 inline mr-1" />
                                {{ $t("files.storage_info") }}
                            </div>
                            <div class="grid grid-cols-2 gap-2 text-xs text-gray-700 dark:text-zinc-300">
                                <div>
                                    <span class="text-gray-500 dark:text-zinc-500">{{ $t("files.shared_count") }}:</span>
                                    {{ storageInfo.shared_count }}
                                </div>
                                <div>
                                    <span class="text-gray-500 dark:text-zinc-500">{{ $t("files.shared_size") }}:</span>
                                    {{ formatFileSize(storageInfo.shared_size) }}
                                </div>
                                <div>
                                    <span class="text-gray-500 dark:text-zinc-500">{{ $t("files.received_count") }}:</span>
                                    {{ storageInfo.received_count }}
                                </div>
                                <div>
                                    <span class="text-gray-500 dark:text-zinc-500">{{ $t("files.received_size") }}:</span>
                                    {{ formatFileSize(storageInfo.received_size) }}
                                </div>
                            </div>
                        </div>

                        <div class="flex gap-2">
                            <button
                                v-if="!listenActive"
                                type="button"
                                class="primary-chip px-4 py-2 text-sm"
                                @click="startListen"
                            >
                                <MaterialDesignIcon icon-name="play" class="w-4 h-4" />
                                {{ $t("files.start_listening") }}
                            </button>
                            <button
                                v-else
                                type="button"
                                class="secondary-chip px-4 py-2 text-sm text-red-600 dark:text-red-300 border-red-200 dark:border-red-500/50"
                                @click="stopListen"
                            >
                                <MaterialDesignIcon icon-name="stop" class="w-4 h-4" />
                                {{ $t("files.stop_listening") }}
                            </button>
                        </div>

                        <div
                            v-if="listenResult"
                            class="p-3 rounded-lg"
                            :class="listenResult.success
                                ? 'bg-green-50 dark:bg-green-900/20 text-green-700 dark:text-green-300'
                                : 'bg-red-50 dark:bg-red-900/20 text-red-700 dark:text-red-300'"
                        >
                            {{ listenResult.message }}
                        </div>

                        <div v-if="lastReceiveEvent" class="p-3 rounded-lg border space-y-2"
                            :class="lastReceiveEvent.status === 'completed'
                                ? 'bg-green-50/80 dark:bg-green-900/15 border-green-200 dark:border-green-800'
                                : 'bg-amber-50/80 dark:bg-amber-900/15 border-amber-200 dark:border-amber-800'"
                        >
                            <div class="text-sm font-semibold text-gray-800 dark:text-zinc-100">
                                {{ lastReceiveEvent.status === 'completed' ? $t('files.file_received') : $t('files.receive_failed') }}
                            </div>
                            <div v-if="lastReceiveEvent.filename" class="text-xs text-gray-600 dark:text-zinc-400">
                                {{ lastReceiveEvent.filename }}
                            </div>
                            <div v-if="lastReceiveEvent.saved_path" class="font-mono text-xs break-all text-gray-700 dark:text-zinc-300">
                                {{ lastReceiveEvent.saved_path }}
                            </div>
                            <div v-if="lastReceiveEvent.error" class="text-xs text-red-600 dark:text-red-400">
                                {{ lastReceiveEvent.error }}
                            </div>
                        </div>
                    </div>

                    <div v-if="activeTab === 'history'" class="space-y-4">
                        <div class="flex items-center justify-between mb-3">
                            <div class="text-sm font-semibold text-gray-700 dark:text-zinc-300">
                                <MaterialDesignIcon icon-name="history" class="w-4 h-4 inline mr-1" />
                                {{ $t("files.transfer_history") }}
                            </div>
                            <button
                                type="button"
                                class="secondary-chip px-3 py-1.5 text-xs"
                                @click="refreshHistory"
                            >
                                <MaterialDesignIcon icon-name="refresh" class="w-4 h-4 inline mr-1" />
                                {{ $t("files.refresh") }}
                            </button>
                        </div>

                        <div v-if="transferHistory.length === 0" class="text-sm text-gray-500 dark:text-zinc-400 text-center py-8">
                            <MaterialDesignIcon icon-name="history" class="w-8 h-8 mx-auto mb-2 opacity-50" />
                            {{ $t("files.no_history") }}
                        </div>
                        <div v-else class="space-y-1">
                            <div
                                v-for="entry in transferHistory"
                                :key="entry.transfer_id"
                                class="flex items-center gap-3 p-2.5 rounded-lg hover:bg-gray-50 dark:hover:bg-zinc-800/50 transition-colors border border-transparent hover:border-gray-200 dark:hover:border-zinc-700"
                            >
                                <div class="shrink-0">
                                    <MaterialDesignIcon
                                        :icon-name="entry.direction === 'outgoing' ? 'upload' : 'download'"
                                        class="w-5 h-5"
                                        :class="entry.status === 'completed'
                                            ? 'text-green-500'
                                            : entry.status === 'error' || entry.status === 'failed'
                                                ? 'text-red-500'
                                                : 'text-gray-400'"
                                    />
                                </div>
                                <div class="min-w-0 flex-1">
                                    <div class="text-sm font-medium text-gray-800 dark:text-zinc-200 truncate" :title="entry.filename || 'Unknown'">
                                        {{ entry.filename || $t("files.unknown") }}
                                    </div>
                                    <div class="text-xs text-gray-500 dark:text-zinc-500">
                                        <span v-if="entry.file_size">{{ formatFileSize(entry.file_size) }} &middot; </span>
                                        {{ entry.direction === 'outgoing' ? $t('files.sent') : $t('files.received') }}
                                        &middot; {{ formatTimestamp(entry.timestamp) }}
                                    </div>
                                </div>
                                <div class="shrink-0">
                                    <span
                                        class="text-xs px-2 py-0.5 rounded-full font-medium"
                                        :class="entry.status === 'completed'
                                            ? 'bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-300'
                                            : 'bg-red-100 dark:bg-red-900/30 text-red-700 dark:text-red-300'"
                                    >
                                        {{ entry.status }}
                                    </span>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</template>

<script>
import MaterialDesignIcon from "../MaterialDesignIcon.vue";
import ToolsPageHeader from "../tools/ToolsPageHeader.vue";
import WebSocketConnection from "../../js/WebSocketConnection";
import ElectronUtils from "../../js/ElectronUtils";
import DialogUtils from "../../js/DialogUtils";
import ToastUtils from "../../js/ToastUtils";

const FILESHARE_LISTEN_PREFS_KEY = "meshchatx.fileshare.listenForm.v1";

export default {
    name: "FileWindowPage",
    components: {
        MaterialDesignIcon,
        ToolsPageHeader,
    },
    data() {
        return {
            activeTab: "send",
            browseTab: "shared",

            sendDestinationHash: null,
            sendFilePath: null,
            sendDescription: "",
            sendTimeout: 60,
            sendInProgress: false,
            sendProgress: 0,
            sendResult: null,

            fetchDestinationHash: null,
            fetchFilePath: null,
            fetchSavePath: null,
            fetchTimeout: 60,
            fetchAllowOverwrite: false,
            fetchInProgress: false,
            fetchProgress: 0,
            fetchResult: null,

            listenAllowedHashes: "",
            listenFetchJail: null,
            listenFetchAllowed: false,
            listenAllowOverwrite: false,
            listenActive: false,
            listenDestinationHash: null,
            listenResult: null,
            lastReceiveEvent: null,
            storageInfo: null,

            sharedFiles: [],
            receivedFiles: [],
            addFileMode: false,
            addFilePath: null,

            transferHistory: [],



            contacts: [],
            showSendContactPicker: false,
            showFetchContactPicker: false,
        };
    },
    watch: {
        listenAllowedHashes() { this.saveListenPrefs(); },
        listenFetchJail() { this.saveListenPrefs(); },
        listenFetchAllowed() { this.saveListenPrefs(); },
        listenAllowOverwrite() { this.saveListenPrefs(); },
    },
    mounted() {
        WebSocketConnection.on("message", this.handleWebSocketMessage);
        this.loadListenPrefs();
        this.refreshListenerStatus();
        this.refreshStorageInfo();
    },
    beforeUnmount() {
        WebSocketConnection.off("message", this.handleWebSocketMessage);
    },
    methods: {
        loadListenPrefs() {
            try {
                const raw = localStorage.getItem(FILESHARE_LISTEN_PREFS_KEY);
                if (!raw) return;
                const o = JSON.parse(raw);
                if (typeof o.listenAllowedHashes === "string") this.listenAllowedHashes = o.listenAllowedHashes;
                if (o.listenFetchJail != null) this.listenFetchJail = o.listenFetchJail;
                if (typeof o.listenFetchAllowed === "boolean") this.listenFetchAllowed = o.listenFetchAllowed;
                if (typeof o.listenAllowOverwrite === "boolean") this.listenAllowOverwrite = o.listenAllowOverwrite;
            } catch {}
        },
        saveListenPrefs() {
            try {
                localStorage.setItem(FILESHARE_LISTEN_PREFS_KEY, JSON.stringify({
                    listenAllowedHashes: this.listenAllowedHashes,
                    listenFetchJail: this.listenFetchJail,
                    listenFetchAllowed: this.listenFetchAllowed,
                    listenAllowOverwrite: this.listenAllowOverwrite,
                }));
            } catch {}
        },
        async refreshListenerStatus() {
            try {
                const response = await window.api.get("/api/v1/rns-fileshare/status");
                const s = response.data;
                if (s?.listening) {
                    this.listenActive = true;
                    this.listenDestinationHash = s.destination_hash;
                    if (Array.isArray(s.allowed_hashes) && s.allowed_hashes.length) {
                        this.listenAllowedHashes = s.allowed_hashes.join("\n");
                    }
                    this.listenFetchAllowed = Boolean(s.fetch_allowed);
                    this.listenFetchJail = s.fetch_jail;
                    this.listenAllowOverwrite = Boolean(s.allow_overwrite);
                }
            } catch {}
        },
        async refreshStorageInfo() {
            try {
                const response = await window.api.get("/api/v1/rns-fileshare/storage");
                this.storageInfo = response.data;
            } catch {}
        },
        async refreshFiles() {
            try {
                const [sharedRes, receivedRes] = await Promise.all([
                    window.api.get("/api/v1/rns-fileshare/files/shared"),
                    window.api.get("/api/v1/rns-fileshare/files/received"),
                ]);
                this.sharedFiles = sharedRes.data.files || [];
                this.receivedFiles = receivedRes.data.files || [];
            } catch {}
        },
        async refreshHistory() {
            try {
                const response = await window.api.get("/api/v1/rns-fileshare/history");
                this.transferHistory = response.data.history || [];
            } catch {}
        },
        handleWebSocketMessage(message) {
            try {
                const data = JSON.parse(message.data);
                if (data.type === "rns_fileshare.transfer.progress") {
                    const tid = data.transfer_id;
                    const p = typeof data.progress === "number" ? data.progress : 0;
                    if (this.sendInProgress && p > 0) this.sendProgress = p;
                    if (this.fetchInProgress && p > 0) this.fetchProgress = p;
                    return;
                }
                if (data.type === "rns_fileshare.receive.completed") {
                    this.lastReceiveEvent = {
                        status: data.status,
                        saved_path: data.saved_path,
                        filename: data.filename,
                        error: data.error,
                    };
                    if (data.status === "completed") {
                        this.refreshFiles();
                        this.refreshStorageInfo();
                        ToastUtils.success(`${this.$t("files.file_received")}: ${data.filename || data.saved_path || ""}`);
                    } else {
                        ToastUtils.error(`${this.$t("files.receive_failed")}: ${data.error || data.status || ""}`);
                    }
                }
            } catch {}
        },
        async pickSendFile() {
            const p = await ElectronUtils.pickFile();
            if (p) {
                this.sendFilePath = p;
                return;
            }
            this.$refs.sendFileInput?.click();
        },
        async onWebSendFilePicked(event) {
            const f = event.target.files?.[0];
            event.target.value = "";
            if (!f) return;
            this.sendFilePath = f.name;
            ToastUtils.info(this.$t("files.uploading_file"));
            try {
                const formData = new FormData();
                formData.append("file", f);
                const response = await window.api.post("/api/v1/rns-fileshare/files/upload", formData);
                this.sendFilePath = response.data.path;
                ToastUtils.success(this.$t("files.file_uploaded"));
            } catch (e) {
                this.sendFilePath = f.name;
                ToastUtils.error(e.response?.data?.message || this.$t("files.failed_to_upload"));
            }
        },
        async pickFetchSaveDirectory() {
            const p = await ElectronUtils.pickDirectory();
            if (p) {
                this.fetchSavePath = p;
                return;
            }
            if (ElectronUtils.isElectron()) return;
            const entered = await DialogUtils.prompt(this.$t("files.web_save_path_prompt"));
            if (entered != null && String(entered).trim()) {
                this.fetchSavePath = String(entered).trim();
            }
        },
        async sendFile() {
            if (!this.sendDestinationHash || this.sendDestinationHash.length !== 32) {
                DialogUtils.alert(this.$t("files.invalid_hash"));
                return;
            }
            if (!this.sendFilePath) {
                DialogUtils.alert(this.$t("files.provide_file_path"));
                return;
            }
            this.sendInProgress = true;
            this.sendProgress = 0;
            this.sendResult = null;

            try {
                const response = await window.api.post("/api/v1/rns-fileshare/send", {
                    destination_hash: this.sendDestinationHash,
                    file_path: this.sendFilePath,
                    description: this.sendDescription,
                    timeout: this.sendTimeout,
                });
                this.sendProgress = 1;
                this.sendResult = {
                    success: true,
                    message: this.$t("files.file_sent"),
                    details: response.data.transfer_id || "",
                };
                this.refreshHistory();
            } catch (e) {
                this.sendResult = {
                    success: false,
                    message: e.response?.data?.message || this.$t("files.failed_to_send"),
                };
            } finally {
                this.sendInProgress = false;
            }
        },
        cancelSend() {
            this.sendInProgress = false;
            this.sendProgress = 0;
        },
        async fetchFile() {
            if (!this.fetchDestinationHash || this.fetchDestinationHash.length !== 32) {
                DialogUtils.alert(this.$t("files.invalid_hash"));
                return;
            }
            if (!this.fetchFilePath) {
                DialogUtils.alert(this.$t("files.provide_remote_path"));
                return;
            }
            this.fetchInProgress = true;
            this.fetchProgress = 0;
            this.fetchResult = null;

            try {
                const response = await window.api.post("/api/v1/rns-fileshare/fetch", {
                    destination_hash: this.fetchDestinationHash,
                    file_path: this.fetchFilePath,
                    timeout: this.fetchTimeout,
                    save_path: this.fetchSavePath || null,
                    allow_overwrite: this.fetchAllowOverwrite,
                });
                this.fetchProgress = 1;
                this.fetchResult = {
                    success: true,
                    message: this.$t("files.file_fetched"),
                    details: response.data.file_path || "",
                };
                this.refreshFiles();
                this.refreshStorageInfo();
                this.refreshHistory();
            } catch (e) {
                this.fetchResult = {
                    success: false,
                    message: e.response?.data?.message || this.$t("files.failed_to_fetch"),
                };
            } finally {
                this.fetchInProgress = false;
            }
        },
        cancelFetch() {
            this.fetchInProgress = false;
            this.fetchProgress = 0;
        },
        async startListen() {
            const allowedHashes = this.listenAllowedHashes
                .split("\n")
                .map((h) => h.trim())
                .filter((h) => h.length === 32);

            if (allowedHashes.length === 0) {
                DialogUtils.alert(this.$t("files.provide_allowed_hash"));
                return;
            }

            this.listenResult = null;

            try {
                const response = await window.api.post("/api/v1/rns-fileshare/listen", {
                    allowed_hashes: allowedHashes,
                    fetch_allowed: this.listenFetchAllowed,
                    fetch_jail: this.listenFetchJail || null,
                    allow_overwrite: this.listenAllowOverwrite,
                });
                this.listenActive = true;
                this.listenDestinationHash = response.data.destination_hash;
                this.listenResult = {
                    success: true,
                    message: response.data.message,
                };
                this.saveListenPrefs();
            } catch (e) {
                this.listenResult = {
                    success: false,
                    message: e.response?.data?.message || this.$t("files.failed_to_listen"),
                };
            }
        },
        async stopListen() {
            try {
                await window.api.post("/api/v1/rns-fileshare/stop");
                this.listenActive = false;
                this.listenDestinationHash = null;
                this.listenResult = null;
            } catch (e) {
                this.listenResult = {
                    success: false,
                    message: e.response?.data?.message || this.$t("files.failed_to_stop"),
                };
            }
        },
        async pickAddFile() {
            const p = await ElectronUtils.pickFile();
            if (p) {
                this.addFilePath = p;
                return;
            }
            this.$refs.addFileInput?.click();
        },
        async onWebAddFilePicked(event) {
            const f = event.target.files?.[0];
            event.target.value = "";
            if (!f) return;
            this.addFilePath = f.name;
            ToastUtils.info(this.$t("files.uploading_file"));
            try {
                const formData = new FormData();
                formData.append("file", f);
                const response = await window.api.post("/api/v1/rns-fileshare/files/upload", formData);
                this.addFilePath = response.data.path;
                ToastUtils.success(this.$t("files.file_uploaded"));
            } catch (e) {
                this.addFilePath = f.name;
                ToastUtils.error(e.response?.data?.message || this.$t("files.failed_to_upload"));
            }
        },
        async copyToShared() {
            if (!this.addFilePath) {
                DialogUtils.alert(this.$t("files.provide_file_path"));
                return;
            }
            try {
                const response = await window.api.post("/api/v1/rns-fileshare/files/copy-to-shared", {
                    source_path: this.addFilePath,
                });
                ToastUtils.success(this.$t("files.file_added"));
                this.addFilePath = "";
                this.addFileMode = false;
                this.refreshFiles();
                this.refreshStorageInfo();
            } catch (e) {
                DialogUtils.alert(e.response?.data?.message || this.$t("files.failed_to_add"));
            }
        },
        async deleteSharedFile(filename) {
            if (!(await DialogUtils.confirm(this.$t("files.delete_confirm", { name: filename })))) return;
            try {
                await window.api.delete(`/api/v1/rns-fileshare/files/shared/${encodeURIComponent(filename)}`);
                ToastUtils.success(this.$t("files.file_deleted"));
                this.refreshFiles();
                this.refreshStorageInfo();
            } catch (e) {
                ToastUtils.error(e.response?.data?.message || this.$t("files.failed_to_delete"));
            }
        },
        async fetchContacts(search) {
            try {
                const params = { limit: 200 };
                if (search) params.search = search;
                const response = await window.api.get("/api/v1/telephone/contacts", { params });
                this.contacts = response.data.contacts || [];
            } catch {
                this.contacts = [];
            }
        },
        selectSendContact(c) {
            if (c.remote_identity_hash) this.sendDestinationHash = c.remote_identity_hash;
            this.showSendContactPicker = false;
        },
        selectFetchContact(c) {
            if (c.remote_identity_hash) this.fetchDestinationHash = c.remote_identity_hash;
            this.showFetchContactPicker = false;
        },
        async openPathInOs(filePath) {
            if (!filePath) return;
            const ok = await ElectronUtils.revealPathInFolderOrCopy(filePath, () =>
                ToastUtils.success(this.$t("common.copied"))
            );
            if (!ok) DialogUtils.alert(filePath);
        },
        getFileIcon(filename) {
            const ext = (filename || "").split(".").pop()?.toLowerCase();
            const icons = {
                pdf: "file-pdf-box",
                zip: "zip-box",
                gz: "zip-box",
                tar: "zip-box",
                rar: "zip-box",
                "7z": "zip-box",
                gif: "file-gif-box",
                jpg: "file-image",
                jpeg: "file-image",
                png: "file-image",
                svg: "file-image",
                webp: "file-image",
                mp3: "file-music",
                wav: "file-music",
                ogg: "file-music",
                flac: "file-music",
                mp4: "file-video",
                avi: "file-video",
                mkv: "file-video",
                mov: "file-video",
                py: "language-python",
                js: "language-javascript",
                ts: "language-typescript",
                vue: "vuejs",
                json: "code-json",
                html: "language-html",
                css: "language-css",
                txt: "text",
                md: "markdown",
                doc: "file-word",
                docx: "file-word",
                xls: "file-excel",
                xlsx: "file-excel",
            };
            return icons[ext] || "file-outline";
        },
        formatFileSize(bytes) {
            if (!bytes || bytes === 0) return "0 B";
            const units = ["B", "KB", "MB", "GB", "TB"];
            const i = Math.floor(Math.log(bytes) / Math.log(1024));
            return (bytes / Math.pow(1024, i)).toFixed(i > 0 ? 1 : 0) + " " + units[i];
        },
        formatDate(timestamp) {
            if (!timestamp) return "";
            const d = new Date(timestamp * 1000);
            return d.toLocaleDateString(undefined, { month: "short", day: "numeric", year: "numeric" });
        },
        formatTimestamp(timestamp) {
            if (!timestamp) return "";
            const d = new Date(timestamp * 1000);
            return d.toLocaleString(undefined, { month: "short", day: "numeric", hour: "2-digit", minute: "2-digit" });
        },
    },
};
</script>
