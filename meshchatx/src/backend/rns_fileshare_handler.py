# SPDX-License-Identifier: 0BSD

import asyncio
import contextlib
import hashlib
import json
import os
import shutil
import time
from collections.abc import Callable
from pathlib import Path

import RNS


class RNSFileShareHandler:
    APP_NAME = "rns_fileshare"
    CHUNK_SIZE = 1024 * 1024

    def __init__(self, reticulum_instance, identity, storage_dir):
        self.reticulum = reticulum_instance
        self.identity = identity
        self.storage_dir = storage_dir
        self.shared_dir = os.path.join(storage_dir, "shared")
        self.received_dir = os.path.join(storage_dir, "received")

        os.makedirs(self.shared_dir, exist_ok=True)
        os.makedirs(self.received_dir, exist_ok=True)

        self.receive_destination = None
        self.active_transfers = {}
        self.allowed_identity_hashes = []
        self._listener_fetch_allowed = False
        self.fetch_jail = None
        self.allow_overwrite_on_receive = False
        self.on_receive_completed = None
        self.transfer_history = []
        self.MAX_HISTORY = 100

    def _emit_receive_event(self, payload):
        if self.on_receive_completed:
            try:
                self.on_receive_completed(payload)
            except Exception:
                pass

    def _add_to_history(self, entry):
        self.transfer_history.insert(0, entry)
        if len(self.transfer_history) > self.MAX_HISTORY:
            self.transfer_history.pop()

    def teardown_receive_destination(self):
        if self.receive_destination is None:
            self.allowed_identity_hashes = []
            return
        dest = self.receive_destination
        self.receive_destination = None
        if self._listener_fetch_allowed:
            with contextlib.suppress(Exception):
                dest.deregister_request_handler("fetch_shared_file")
            self._listener_fetch_allowed = False
        self.allowed_identity_hashes = []
        with contextlib.suppress(Exception):
            RNS.Transport.deregister_destination(dest)

    def get_listener_status(self):
        if self.receive_destination is None:
            return {
                "listening": False,
                "destination_hash": None,
                "allowed_hashes": [],
                "fetch_allowed": False,
                "fetch_jail": None,
                "allow_overwrite": False,
                "shared_dir": self.shared_dir,
                "received_dir": self.received_dir,
            }
        return {
            "listening": True,
            "destination_hash": self.receive_destination.hash.hex(),
            "allowed_hashes": [h.hex() for h in self.allowed_identity_hashes],
            "fetch_allowed": self._listener_fetch_allowed,
            "fetch_jail": self.fetch_jail,
            "allow_overwrite": self.allow_overwrite_on_receive,
            "shared_dir": self.shared_dir,
            "received_dir": self.received_dir,
        }

    def setup_receive_destination(
        self,
        allowed_hashes=None,
        fetch_allowed=False,
        fetch_jail=None,
        allow_overwrite=False,
    ):
        self.teardown_receive_destination()

        self.allowed_identity_hashes = []
        if allowed_hashes:
            self.allowed_identity_hashes = [
                bytes.fromhex(h) if isinstance(h, str) else h for h in allowed_hashes
            ]

        self.fetch_jail = fetch_jail or self.shared_dir
        self.allow_overwrite_on_receive = allow_overwrite
        self._listener_fetch_allowed = bool(fetch_allowed)

        if self._listener_fetch_allowed and self.fetch_jail:
            with contextlib.suppress(OSError):
                os.makedirs(self.fetch_jail, exist_ok=True)

        identity_path = os.path.join(RNS.Reticulum.identitypath, self.APP_NAME)
        if os.path.isfile(identity_path):
            receive_identity = RNS.Identity.from_file(identity_path)
        else:
            receive_identity = RNS.Identity()
            receive_identity.to_file(identity_path)

        self.receive_destination = RNS.Destination(
            receive_identity,
            RNS.Destination.IN,
            RNS.Destination.SINGLE,
            self.APP_NAME,
            "receive",
        )

        self.receive_destination.set_link_established_callback(
            self._client_link_established,
        )

        if fetch_allowed:
            self.receive_destination.register_request_handler(
                "fetch_shared_file",
                response_generator=self._fetch_request,
                allow=RNS.Destination.ALLOW_LIST,
                allowed_list=self.allowed_identity_hashes,
            )
            self._listener_fetch_allowed = True

        return self.receive_destination.hash.hex()

    def _client_link_established(self, link):
        link.set_remote_identified_callback(self._receive_sender_identified)
        link.set_resource_strategy(RNS.Link.ACCEPT_APP)
        link.set_resource_callback(self._receive_resource_callback)
        link.set_resource_started_callback(self._receive_resource_started)
        link.set_resource_concluded_callback(self._receive_resource_concluded)

    def _receive_sender_identified(self, link, identity):
        if self.allowed_identity_hashes and identity.hash not in self.allowed_identity_hashes:
            link.teardown()

    def _receive_resource_callback(self, resource):
        if not self.allowed_identity_hashes:
            return True
        sender_identity = resource.link.get_remote_identity()
        if sender_identity and sender_identity.hash in self.allowed_identity_hashes:
            return True
        return False

    def _receive_resource_started(self, resource):
        transfer_id = resource.hash.hex()
        self.active_transfers[transfer_id] = {
            "resource": resource,
            "status": "receiving",
            "started_at": time.time(),
            "direction": "incoming",
        }

    def _receive_resource_concluded(self, resource):
        transfer_id = resource.hash.hex()
        if resource.status == RNS.Resource.COMPLETE:
            if resource.metadata:
                try:
                    metadata = json.loads(resource.metadata["name"].decode("utf-8"))
                    filename = os.path.basename(metadata.get("filename", "unknown"))
                    description = metadata.get("description", "")

                    save_dir = self.received_dir
                    os.makedirs(save_dir, exist_ok=True)

                    saved_filename = os.path.join(save_dir, filename)
                    counter = 0

                    if self.allow_overwrite_on_receive:
                        if os.path.isfile(saved_filename):
                            try:
                                os.unlink(saved_filename)
                            except OSError:
                                pass

                    while os.path.isfile(saved_filename):
                        counter += 1
                        base, ext = os.path.splitext(filename)
                        saved_filename = os.path.join(save_dir, f"{base}.{counter}{ext}")

                    shutil.move(resource.data.name, saved_filename)
                    file_size = os.path.getsize(saved_filename)

                    if transfer_id in self.active_transfers:
                        self.active_transfers[transfer_id]["status"] = "completed"
                        self.active_transfers[transfer_id]["saved_path"] = saved_filename
                        self.active_transfers[transfer_id]["filename"] = filename

                    entry = {
                        "transfer_id": transfer_id,
                        "status": "completed",
                        "saved_path": saved_filename,
                        "filename": filename,
                        "description": description,
                        "file_size": file_size,
                        "direction": "incoming",
                        "timestamp": time.time(),
                        "error": None,
                    }
                    self._add_to_history(entry)
                    self._emit_receive_event(entry)
                except Exception as e:
                    if transfer_id in self.active_transfers:
                        self.active_transfers[transfer_id]["status"] = "error"
                        self.active_transfers[transfer_id]["error"] = str(e)
                    entry = {
                        "transfer_id": transfer_id,
                        "status": "error",
                        "saved_path": None,
                        "filename": None,
                        "description": "",
                        "file_size": 0,
                        "direction": "incoming",
                        "timestamp": time.time(),
                        "error": str(e),
                    }
                    self._add_to_history(entry)
                    self._emit_receive_event(entry)
        elif transfer_id in self.active_transfers:
            self.active_transfers[transfer_id]["status"] = "failed"
            entry = {
                "transfer_id": transfer_id,
                "status": "failed",
                "saved_path": None,
                "filename": None,
                "description": "",
                "file_size": 0,
                "direction": "incoming",
                "timestamp": time.time(),
                "error": None,
            }
            self._add_to_history(entry)
            self._emit_receive_event(entry)

    def _fetch_request(self, path, data, request_id, link_id, remote_identity, requested_at):
        if not self.fetch_jail:
            return self.REQ_FETCH_NOT_ALLOWED

        if isinstance(data, bytes):
            try:
                data = data.decode("utf-8")
            except UnicodeDecodeError:
                return False

        if data.startswith(self.fetch_jail + "/"):
            data = data.replace(self.fetch_jail + "/", "")
        file_path = os.path.realpath(os.path.join(self.fetch_jail, data.lstrip("/")))
        jail_real = os.path.realpath(self.fetch_jail)
        if file_path != jail_real and not file_path.startswith(jail_real + os.sep):
            return self.REQ_FETCH_NOT_ALLOWED

        target_link = None
        for link in RNS.Transport.active_links:
            if link.link_id == link_id:
                target_link = link
                break

        if not os.path.isfile(file_path):
            return False

        if target_link:
            try:
                metadata = {
                    "name": json.dumps({
                        "filename": os.path.basename(file_path),
                        "description": "Fetched via RNS FileShare",
                    }).encode("utf-8"),
                }
                RNS.Resource(
                    open(file_path, "rb"),
                    target_link,
                    metadata=metadata,
                    auto_compress=False,
                )
                return True
            except Exception:
                return False

        return None

    async def send_file(
        self,
        destination_hash: bytes,
        file_path: str,
        description: str = "",
        timeout: float = RNS.Transport.PATH_REQUEST_TIMEOUT,
        on_progress: Callable[[float], None] | None = None,
        on_transfer_started: Callable[[str], None] | None = None,
    ):
        file_path = os.path.expanduser(file_path)
        if not os.path.isfile(file_path):
            msg = f"File not found: {file_path}"
            raise FileNotFoundError(msg)

        if not RNS.Transport.has_path(destination_hash):
            RNS.Transport.request_path(destination_hash)

        timeout_after = time.time() + timeout
        while not RNS.Transport.has_path(destination_hash) and time.time() < timeout_after:
            await asyncio.sleep(0.1)

        if not RNS.Transport.has_path(destination_hash):
            msg = "Path not found to destination"
            raise TimeoutError(msg)

        receiver_identity = RNS.Identity.recall(destination_hash)
        receiver_destination = RNS.Destination(
            receiver_identity,
            RNS.Destination.OUT,
            RNS.Destination.SINGLE,
            self.APP_NAME,
            "receive",
        )

        link = RNS.Link(receiver_destination)
        timeout_after = time.time() + timeout
        while link.status != RNS.Link.ACTIVE and time.time() < timeout_after:
            await asyncio.sleep(0.1)

        if link.status != RNS.Link.ACTIVE:
            msg = "Could not establish link to destination"
            raise TimeoutError(msg)

        link.identify(self.identity)

        file_size = os.path.getsize(file_path)
        metadata = {
            "name": json.dumps({
                "filename": os.path.basename(file_path),
                "description": description,
                "file_size": file_size,
            }).encode("utf-8"),
        }

        def progress_callback(resource):
            if on_progress:
                progress = resource.get_progress()
                on_progress(progress)

        resource = RNS.Resource(
            open(file_path, "rb"),
            link,
            metadata=metadata,
            callback=progress_callback,
            progress_callback=progress_callback,
            auto_compress=False,
        )

        transfer_id = resource.hash.hex()
        self.active_transfers[transfer_id] = {
            "resource": resource,
            "status": "sending",
            "started_at": time.time(),
            "file_path": file_path,
            "direction": "outgoing",
            "file_size": file_size,
        }
        if on_transfer_started:
            try:
                on_transfer_started(transfer_id)
            except Exception:
                pass

        while resource.status < RNS.Resource.COMPLETE:
            await asyncio.sleep(0.1)
            if resource.status > RNS.Resource.COMPLETE:
                msg = "File was not accepted by destination"
                raise Exception(msg)

        if resource.status == RNS.Resource.COMPLETE:
            if transfer_id in self.active_transfers:
                self.active_transfers[transfer_id]["status"] = "completed"
            link.teardown()
            entry = {
                "transfer_id": transfer_id,
                "status": "completed",
                "file_path": file_path,
                "filename": os.path.basename(file_path),
                "description": description,
                "file_size": file_size,
                "direction": "outgoing",
                "timestamp": time.time(),
                "error": None,
            }
            self._add_to_history(entry)
            return entry

        if transfer_id in self.active_transfers:
            self.active_transfers[transfer_id]["status"] = "failed"
        link.teardown()
        msg = "Transfer failed"
        raise Exception(msg)

    async def fetch_file(
        self,
        destination_hash: bytes,
        file_path: str,
        timeout: float = RNS.Transport.PATH_REQUEST_TIMEOUT,
        on_progress: Callable[[float], None] | None = None,
        save_path: str | None = None,
        allow_overwrite: bool = False,
        on_transfer_started: Callable[[str], None] | None = None,
    ):
        if not RNS.Transport.has_path(destination_hash):
            RNS.Transport.request_path(destination_hash)

        timeout_after = time.time() + timeout
        while not RNS.Transport.has_path(destination_hash) and time.time() < timeout_after:
            await asyncio.sleep(0.1)

        if not RNS.Transport.has_path(destination_hash):
            msg = "Path not found to destination"
            raise TimeoutError(msg)

        listener_identity = RNS.Identity.recall(destination_hash)
        listener_destination = RNS.Destination(
            listener_identity,
            RNS.Destination.OUT,
            RNS.Destination.SINGLE,
            self.APP_NAME,
            "receive",
        )

        link = RNS.Link(listener_destination)
        timeout_after = time.time() + timeout
        while link.status != RNS.Link.ACTIVE and time.time() < timeout_after:
            await asyncio.sleep(0.1)

        if link.status != RNS.Link.ACTIVE:
            msg = "Could not establish link to destination"
            raise TimeoutError(msg)

        link.identify(self.identity)

        request_resolved = False
        request_status = "unknown"
        resource_resolved = False
        resource_status = "unrequested"
        current_resource = None

        def request_response(request_receipt):
            nonlocal request_resolved, request_status
            if not request_receipt.response:
                request_status = "not_found"
            elif request_receipt.response is None:
                request_status = "remote_error"
            else:
                request_status = "found"
            request_resolved = True

        def request_failed(request_receipt):
            nonlocal request_resolved, request_status
            request_status = "unknown"
            request_resolved = True

        def fetch_resource_started(resource):
            nonlocal resource_status, current_resource
            current_resource = resource
            if on_transfer_started and hasattr(resource, "hash") and resource.hash:
                try:
                    on_transfer_started(resource.hash.hex())
                except Exception:
                    pass

            def progress_callback(resource):
                if on_progress:
                    progress = resource.get_progress()
                    on_progress(progress)

            current_resource.progress_callback(progress_callback)
            resource_status = "started"

        saved_filename = None
        received_filename = None

        def fetch_resource_concluded(resource):
            nonlocal resource_resolved, resource_status, saved_filename, received_filename
            if resource.status == RNS.Resource.COMPLETE:
                if resource.metadata:
                    try:
                        metadata = json.loads(resource.metadata["name"].decode("utf-8"))
                        filename = metadata.get("filename", "unknown")
                        received_filename = filename

                        if save_path:
                            save_dir = os.path.abspath(os.path.expanduser(save_path))
                            os.makedirs(save_dir, exist_ok=True)
                            saved_filename = os.path.join(save_dir, filename)
                        else:
                            save_dir = self.received_dir
                            os.makedirs(save_dir, exist_ok=True)
                            saved_filename = os.path.join(save_dir, filename)

                        counter = 0
                        if allow_overwrite:
                            if os.path.isfile(saved_filename):
                                try:
                                    os.unlink(saved_filename)
                                except OSError:
                                    pass

                        while os.path.isfile(saved_filename):
                            counter += 1
                            base, ext = os.path.splitext(filename)
                            saved_filename = os.path.join(
                                os.path.dirname(saved_filename) if save_path else save_dir,
                                f"{base}.{counter}{ext}",
                            )

                        shutil.move(resource.data.name, saved_filename)
                        resource_status = "completed"
                    except Exception as e:
                        resource_status = "error"
                else:
                    resource_status = "error"
            else:
                resource_status = "failed"

            resource_resolved = True

        link.set_resource_strategy(RNS.Link.ACCEPT_ALL)
        link.set_resource_started_callback(fetch_resource_started)
        link.set_resource_concluded_callback(fetch_resource_concluded)
        link.request(
            "fetch_shared_file",
            data=file_path,
            response_callback=request_response,
            failed_callback=request_failed,
        )

        while not request_resolved:
            await asyncio.sleep(0.1)

        if request_status == "not_found":
            link.teardown()
            msg = f"File not found on remote: {file_path}"
            raise FileNotFoundError(msg)
        if request_status == "remote_error":
            link.teardown()
            msg = "Remote error during fetch request"
            raise Exception(msg)
        if request_status == "unknown":
            link.teardown()
            msg = "Unknown error during fetch request"
            raise Exception(msg)

        while not resource_resolved:
            await asyncio.sleep(0.1)

        if resource_status == "completed":
            link.teardown()
            file_size = os.path.getsize(saved_filename) if saved_filename else 0
            entry = {
                "transfer_id": current_resource.hash.hex() if current_resource else "unknown",
                "status": "completed",
                "file_path": saved_filename,
                "filename": received_filename,
                "description": "Fetched from peer",
                "file_size": file_size,
                "direction": "incoming",
                "timestamp": time.time(),
                "error": None,
            }
            self._add_to_history(entry)
            return entry

        link.teardown()
        msg = f"Transfer failed: {resource_status}"
        raise Exception(msg)

    def get_transfer_status(self, transfer_id: str):
        if transfer_id in self.active_transfers:
            transfer = self.active_transfers[transfer_id]
            resource = transfer.get("resource")
            if resource:
                progress = resource.get_progress()
                return {
                    "transfer_id": transfer_id,
                    "status": transfer["status"],
                    "progress": progress,
                    "file_path": transfer.get("file_path"),
                    "saved_path": transfer.get("saved_path"),
                    "filename": transfer.get("filename"),
                    "file_size": transfer.get("file_size", 0),
                    "direction": transfer.get("direction", "unknown"),
                    "error": transfer.get("error"),
                }
        return None

    def list_shared_files(self):
        files = []
        if os.path.isdir(self.shared_dir):
            for fname in os.listdir(self.shared_dir):
                fpath = os.path.join(self.shared_dir, fname)
                if os.path.isfile(fpath):
                    stat = os.stat(fpath)
                    files.append({
                        "name": fname,
                        "path": fpath,
                        "size": stat.st_size,
                        "modified": stat.st_mtime,
                    })
        return sorted(files, key=lambda x: x["name"])

    def list_received_files(self):
        files = []
        if os.path.isdir(self.received_dir):
            for fname in os.listdir(self.received_dir):
                fpath = os.path.join(self.received_dir, fname)
                if os.path.isfile(fpath):
                    stat = os.stat(fpath)
                    files.append({
                        "name": fname,
                        "path": fpath,
                        "size": stat.st_size,
                        "modified": stat.st_mtime,
                    })
        return sorted(files, key=lambda x: x["name"])

    def _dedup_path(self, dest):
        base, ext = os.path.splitext(dest)
        counter = 0
        while os.path.exists(dest):
            counter += 1
            dest = f"{base}.{counter}{ext}"
        return dest

    def move_to_shared(self, filename: str, source_path: str) -> str:
        dest = self._dedup_path(os.path.join(self.shared_dir, os.path.basename(filename)))
        shutil.move(source_path, dest)
        return dest

    def upload_to_shared(self, filename: str, data: bytes) -> str:
        dest = self._dedup_path(os.path.join(self.shared_dir, os.path.basename(filename)))
        with open(dest, "wb") as f:
            f.write(data)
        return dest

    def copy_to_shared(self, source_path: str) -> str:
        source_path = os.path.expanduser(source_path)
        if not os.path.isfile(source_path):
            msg = f"File not found: {source_path}"
            raise FileNotFoundError(msg)
        dest = os.path.join(self.shared_dir, os.path.basename(source_path))
        counter = 0
        while os.path.exists(dest):
            counter += 1
            base, ext = os.path.splitext(os.path.basename(source_path))
            dest = os.path.join(self.shared_dir, f"{base}.{counter}{ext}")
        shutil.copy2(source_path, dest)
        return dest

    def delete_shared_file(self, filename: str) -> bool:
        fpath = os.path.join(self.shared_dir, filename)
        fpath = os.path.realpath(fpath)
        if not fpath.startswith(os.path.realpath(self.shared_dir) + os.sep) and fpath != os.path.realpath(self.shared_dir):
            return False
        if os.path.isfile(fpath):
            os.unlink(fpath)
            return True
        return False

    def get_transfer_history(self, limit: int = 50):
        return self.transfer_history[:limit]

    def get_storage_info(self):
        shared_size = 0
        shared_count = 0
        received_size = 0
        received_count = 0

        if os.path.isdir(self.shared_dir):
            for fname in os.listdir(self.shared_dir):
                fpath = os.path.join(self.shared_dir, fname)
                if os.path.isfile(fpath):
                    shared_size += os.path.getsize(fpath)
                    shared_count += 1

        if os.path.isdir(self.received_dir):
            for fname in os.listdir(self.received_dir):
                fpath = os.path.join(self.received_dir, fname)
                if os.path.isfile(fpath):
                    received_size += os.path.getsize(fpath)
                    received_count += 1

        return {
            "shared_dir": self.shared_dir,
            "received_dir": self.received_dir,
            "shared_count": shared_count,
            "shared_size": shared_size,
            "received_count": received_count,
            "received_size": received_size,
        }
