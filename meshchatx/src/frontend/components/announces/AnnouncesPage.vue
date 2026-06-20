<template>
    <div class="flex flex-col flex-1 overflow-hidden min-w-0 bg-slate-50 dark:bg-zinc-950">
        <div class="flex-1 overflow-y-auto w-full px-4 md:px-5 lg:px-8 py-6 pb-[max(1.5rem,env(safe-area-inset-bottom))]">
            <div class="space-y-4 w-full max-w-5xl mx-auto">
                <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
                    <div>
                        <h1 class="text-xl font-bold text-gray-900 dark:text-white">
                            <MaterialDesignIcon icon-name="bullhorn" class="w-5 h-5 inline mr-1.5" />
                            {{ $t("announces.title") }}
                        </h1>
                        <p class="text-sm text-gray-500 dark:text-zinc-400 mt-0.5">
                            {{ $t("announces.description") }}
                        </p>
                    </div>
                    <div class="flex items-center gap-2">
                        <div class="relative flex-1 sm:w-56">
                            <MaterialDesignIcon
                                icon-name="magnify"
                                class="absolute left-2.5 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400 pointer-events-none"
                            />
                            <input
                                v-model="searchQuery"
                                type="text"
                                class="input-field pl-9! text-sm"
                                :placeholder="$t('announces.search_placeholder')"
                                @input="onSearch"
                            />
                        </div>
                        <select
                            v-model="selectedAspect"
                            class="input-field text-sm w-auto"
                            @change="fetchAnnounces"
                        >
                            <option value="">{{ $t("announces.all_aspects") }}</option>
                            <option value="lxmf.delivery">LXMF</option>
                            <option value="lxst.telephony">LXST (Calls)</option>
                            <option value="nomadnetwork.node">Nomad Network</option>
                            <option value="rrc.hub">RRC Hub</option>
                        </select>
                        <button
                            type="button"
                            class="secondary-chip p-2.5!"
                            :title="$t('common.refresh')"
                            @click="fetchAnnounces"
                        >
                            <MaterialDesignIcon
                                icon-name="refresh"
                                class="w-4 h-4"
                                :class="{ 'animate-spin-reverse': isLoading }"
                            />
                        </button>
                    </div>
                </div>

                <div v-if="isLoading && announces.length === 0" class="space-y-3">
                    <div v-for="i in 4" :key="'skel-' + i" class="glass-card p-4 space-y-3">
                        <div class="h-4 w-40 bg-gray-200 dark:bg-zinc-700 rounded animate-pulse" />
                        <div class="h-3 w-full bg-gray-100 dark:bg-zinc-800 rounded animate-pulse" />
                        <div class="h-3 w-3/4 bg-gray-100 dark:bg-zinc-800 rounded animate-pulse" />
                    </div>
                </div>

                <div v-else-if="announces.length === 0" class="text-center py-12">
                    <MaterialDesignIcon icon-name="bullhorn-outline" class="w-12 h-12 mx-auto mb-3 text-gray-300 dark:text-zinc-600" />
                    <p class="text-sm text-gray-500 dark:text-zinc-400">{{ $t("announces.no_announces") }}</p>
                </div>

                <div v-else class="space-y-2">
                    <div
                        v-for="a in announces"
                        :key="a.id"
                        class="glass-card p-3.5 space-y-2"
                    >
                        <div class="flex items-start justify-between gap-3">
                            <div class="min-w-0 flex-1">
                                <div class="font-medium text-gray-800 dark:text-zinc-200 truncate">
                                    {{ a.display_name || a.custom_display_name || $t("announces.anonymous") }}
                                </div>
                                <div class="flex flex-wrap gap-1.5 mt-1">
                                    <span
                                        class="text-xs px-1.5 py-0.5 rounded font-mono font-semibold"
                                        :class="aspectClass(a.aspect)"
                                    >
                                        {{ a.aspect }}
                                    </span>
                                    <span
                                        class="text-xs px-1.5 py-0.5 rounded bg-gray-100 dark:bg-zinc-800 text-gray-600 dark:text-zinc-400"
                                    >
                                        {{ a.hops }} {{ $t("announces.hops") }}
                                    </span>
                                    <span
                                        v-if="a.quality != null"
                                        class="text-xs px-1.5 py-0.5 rounded"
                                        :class="qualityClass(a.quality)"
                                    >
                                        {{ Math.round(a.quality * 100) }}%
                                    </span>
                                </div>
                            </div>
                        </div>

                        <div class="space-y-1">
                            <div class="flex items-center gap-1.5 text-xs">
                                <span class="shrink-0 px-1 py-0.5 rounded bg-indigo-100 dark:bg-indigo-900/40 text-indigo-700 dark:text-indigo-300 font-mono font-semibold">RNS ID</span>
                                <span class="text-gray-600 dark:text-zinc-400 font-mono truncate min-w-0">{{ a.identity_hash }}</span>
                                <button
                                    type="button"
                                    class="shrink-0 text-gray-400 hover:text-indigo-500 transition-colors"
                                    :title="$t('common.copy')"
                                    @click="copyHash(a.identity_hash, $t('announces.rns_hash_copied'))"
                                >
                                    <MaterialDesignIcon icon-name="content-copy" class="w-3.5 h-3.5" />
                                </button>
                                <button
                                    type="button"
                                    class="shrink-0 text-gray-400 hover:text-indigo-500 transition-colors ml-auto"
                                    :title="$t('files.send_file')"
                                    @click="useForSend(a.identity_hash)"
                                >
                                    <MaterialDesignIcon icon-name="upload" class="w-3.5 h-3.5" />
                                </button>
                            </div>
                            <div class="flex items-center gap-1.5 text-xs">
                                <span class="shrink-0 px-1 py-0.5 rounded bg-amber-100 dark:bg-amber-900/40 text-amber-700 dark:text-amber-300 font-mono font-semibold">DEST</span>
                                <span class="text-gray-500 dark:text-zinc-500 font-mono truncate min-w-0">{{ a.destination_hash }}</span>
                                <button
                                    type="button"
                                    class="shrink-0 text-gray-400 hover:text-amber-500 transition-colors"
                                    :title="$t('common.copy')"
                                    @click="copyHash(a.destination_hash, $t('announces.dest_hash_copied'))"
                                >
                                    <MaterialDesignIcon icon-name="content-copy" class="w-3.5 h-3.5" />
                                </button>
                            </div>
                            <div v-if="a.lxmf_destination_hash && a.lxmf_destination_hash !== a.destination_hash" class="flex items-center gap-1.5 text-xs">
                                <span class="shrink-0 px-1 py-0.5 rounded bg-emerald-100 dark:bg-emerald-900/40 text-emerald-700 dark:text-emerald-300 font-mono font-semibold">LXMF</span>
                                <span class="text-gray-500 dark:text-zinc-500 font-mono truncate min-w-0">{{ a.lxmf_destination_hash }}</span>
                                <button
                                    type="button"
                                    class="shrink-0 text-gray-400 hover:text-emerald-500 transition-colors"
                                    :title="$t('common.copy')"
                                    @click="copyHash(a.lxmf_destination_hash, $t('announces.lxmf_hash_copied'))"
                                >
                                    <MaterialDesignIcon icon-name="content-copy" class="w-3.5 h-3.5" />
                                </button>
                            </div>
                        </div>
                    </div>
                </div>

                <div v-if="hasMore" class="text-center py-4">
                    <button
                        type="button"
                        class="secondary-chip px-4 py-2 text-sm"
                        :disabled="isLoading"
                        @click="loadMore"
                    >
                        <MaterialDesignIcon icon-name="chevron-down" class="w-4 h-4" />
                        {{ $t("announces.load_more") }}
                    </button>
                </div>
            </div>
        </div>
    </div>
</template>

<script>
import MaterialDesignIcon from "../MaterialDesignIcon.vue";
import ToastUtils from "../../js/ToastUtils";

const PAGE_SIZE = 30;

export default {
    name: "AnnouncesPage",
    components: { MaterialDesignIcon },
    data() {
        return {
            announces: [],
            isLoading: false,
            searchQuery: "",
            selectedAspect: "",
            offset: 0,
            totalCount: 0,
            searchTimeout: null,
        };
    },
    computed: {
        hasMore() {
            return this.announces.length < this.totalCount;
        },
    },
    mounted() {
        this.fetchAnnounces();
    },
    methods: {
        async fetchAnnounces() {
            this.isLoading = true;
            this.offset = 0;
            try {
                const params = {
                    limit: PAGE_SIZE,
                    offset: 0,
                };
                if (this.selectedAspect) params.aspect = this.selectedAspect;
                if (this.searchQuery) params.search = this.searchQuery;
                const response = await window.api.get("/api/v1/announces", { params });
                this.announces = response.data.announces || [];
                this.totalCount = response.data.total_count || 0;
            } catch {
                this.announces = [];
                this.totalCount = 0;
            } finally {
                this.isLoading = false;
            }
        },
        async loadMore() {
            this.isLoading = true;
            this.offset = this.announces.length;
            try {
                const params = {
                    limit: PAGE_SIZE,
                    offset: this.offset,
                };
                if (this.selectedAspect) params.aspect = this.selectedAspect;
                if (this.searchQuery) params.search = this.searchQuery;
                const response = await window.api.get("/api/v1/announces", { params });
                const more = response.data.announces || [];
                this.announces = [...this.announces, ...more];
                this.totalCount = response.data.total_count || 0;
            } catch {
                // ignore
            } finally {
                this.isLoading = false;
            }
        },
        onSearch() {
            clearTimeout(this.searchTimeout);
            this.searchTimeout = setTimeout(() => {
                this.fetchAnnounces();
            }, 300);
        },
        aspectClass(aspect) {
            if (aspect?.startsWith("lxmf")) return "bg-blue-100 dark:bg-blue-900/30 text-blue-700 dark:text-blue-300";
            if (aspect?.startsWith("lxst")) return "bg-purple-100 dark:bg-purple-900/30 text-purple-700 dark:text-purple-300";
            if (aspect?.startsWith("nomadnetwork")) return "bg-teal-100 dark:bg-teal-900/30 text-teal-700 dark:text-teal-300";
            if (aspect?.startsWith("rrc")) return "bg-orange-100 dark:bg-orange-900/30 text-orange-700 dark:text-orange-300";
            return "bg-gray-100 dark:bg-zinc-800 text-gray-600 dark:text-zinc-400";
        },
        qualityClass(quality) {
            if (quality >= 0.8) return "bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-300";
            if (quality >= 0.5) return "bg-yellow-100 dark:bg-yellow-900/30 text-yellow-700 dark:text-yellow-300";
            return "bg-red-100 dark:bg-red-900/30 text-red-700 dark:text-red-300";
        },
        copyHash(hash, message) {
            if (!hash) return;
            navigator.clipboard.writeText(hash).then(() => {
                ToastUtils.success(message || this.$t("common.copied"));
            }).catch(() => {
                ToastUtils.warning("Could not copy to clipboard");
            });
        },
        useForSend(hash) {
            if (!hash) return;
            this.$router.push({
                name: "files",
                query: { destination: hash },
            });
        },
    },
};
</script>
