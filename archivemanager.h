#pragma once
#include <QObject>
#include <QAbstractListModel>
#include <QThread>
#include <QStringList>
#include <QFileInfo>
#include <QDir>
#include <QUrl>
#include <QAtomicInt>
#include <QSettings>

struct ArchiveEntry { QString path; qint64 size=0; bool isDir=false; QString modified; };
Q_DECLARE_METATYPE(ArchiveEntry)
Q_DECLARE_METATYPE(QVector<ArchiveEntry>)

class ArchiveEntryModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int fileCount READ fileCount NOTIFY statsChanged)
    Q_PROPERTY(int dirCount READ dirCount NOTIFY statsChanged)
    Q_PROPERTY(qint64 totalSize READ totalSize NOTIFY statsChanged)
    Q_PROPERTY(QString totalSizeFormatted READ totalSizeFormatted NOTIFY statsChanged)
public:
    enum Roles { PathRole=Qt::UserRole+1,SizeRole,IsDirRole,ModifiedRole,FileNameRole };
    explicit ArchiveEntryModel(QObject *p=nullptr);
    int rowCount(const QModelIndex &p={}) const override;
    QVariant data(const QModelIndex &i,int role) const override;
    QHash<int,QByteArray> roleNames() const override;
    void setEntries(const QVector<ArchiveEntry>&e); void clear();
    int fileCount() const; int dirCount() const;
    qint64 totalSize() const; QString totalSizeFormatted() const;
signals: void statsChanged();
private: QVector<ArchiveEntry> m_entries;
};

class ArchiveWorker : public QObject {
    Q_OBJECT
public:
    explicit ArchiveWorker(QObject *p=nullptr);
    void requestCancel();
public slots:
    void listContents(const QString &path);
    void extract(const QString &path,const QString &dest,qint64 total,int conflict);
    void create(const QString &out,const QStringList &src,const QString &fmt);
signals:
    void progress(qreal val,const QString &entry);
    void contentsReady(const QVector<ArchiveEntry>&entries);
    void finished(bool ok,const QString &msg);
private: QAtomicInt m_cancelRequested;
};

class ArchiveManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString archivePath READ archivePath NOTIFY archivePathChanged)
    Q_PROPERTY(QString archiveName READ archiveName NOTIFY archivePathChanged)
    Q_PROPERTY(QString archiveBaseName READ archiveBaseName NOTIFY archivePathChanged)
    Q_PROPERTY(QString archiveSize READ archiveSize NOTIFY archivePathChanged)
    Q_PROPERTY(QString archiveType READ archiveType NOTIFY archivePathChanged)
    Q_PROPERTY(QString destinationPath READ destinationPath WRITE setDestinationPath NOTIFY destinationPathChanged)
    Q_PROPERTY(qreal progress READ progress NOTIFY progressChanged)
    Q_PROPERTY(QString currentEntry READ currentEntry NOTIFY progressChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorChanged)
    Q_PROPERTY(int conflictMode READ conflictMode WRITE setConflictMode NOTIFY conflictModeChanged)
    Q_PROPERTY(int operationType READ operationType NOTIFY operationTypeChanged)
    Q_PROPERTY(bool createParentFolder READ createParentFolder WRITE setCreateParentFolder NOTIFY createParentFolderChanged)
    Q_PROPERTY(ArchiveEntryModel* contents READ contents CONSTANT)
    Q_PROPERTY(QStringList createFiles READ createFiles NOTIFY createFilesChanged)
    Q_PROPERTY(QString createFilesSize READ createFilesSize NOTIFY createFilesChanged)
public:
    explicit ArchiveManager(QObject *p=nullptr); ~ArchiveManager();

    QString archivePath() const; QString archiveName() const;
    QString archiveBaseName() const;
    QString archiveSize() const; QString archiveType() const;
    QString destinationPath() const; qreal progress() const;
    QString currentEntry() const; QString status() const;
    bool busy() const; QString errorMessage() const;
    int conflictMode() const; int operationType() const;
    bool createParentFolder() const;
    ArchiveEntryModel* contents() const;
    QStringList createFiles() const; QString createFilesSize() const;

    void setDestinationPath(const QString &p);
    void setConflictMode(int m);
    void setCreateParentFolder(bool v);

    Q_INVOKABLE void openArchive(const QString &path);
    Q_INVOKABLE void extract();
    Q_INVOKABLE void cancel();
    Q_INVOKABLE void clear();
    Q_INVOKABLE void addFiles(const QStringList &paths);
    Q_INVOKABLE void removeFile(int index);
    Q_INVOKABLE void clearFiles();
    Q_INVOKABLE void createArchive(const QString &out,const QString &fmt);

    Q_INVOKABLE int countConflicts() const;
    Q_INVOKABLE bool destinationExists() const;
    Q_INVOKABLE void setDestinationFolder(const QString &folder);

    Q_INVOKABLE static QString formatBytes(qint64 b);
    Q_INVOKABLE static QStringList supportedFormats();
    Q_INVOKABLE static bool fileExists(const QString &p);
    Q_INVOKABLE QString suggestedDestination() const;
    Q_INVOKABLE QString fileName(const QString &p) const;
    Q_INVOKABLE QString fileSize(const QString &p) const;
    Q_INVOKABLE bool isDirectory(const QString &p) const;

signals:
    void archivePathChanged(); void destinationPathChanged();
    void progressChanged(); void statusChanged();
    void busyChanged(); void errorChanged();
    void conflictModeChanged(); void operationTypeChanged();
    void createParentFolderChanged();
    void createFilesChanged();
    void extractionComplete(); void creationComplete();

private:
    void setStatus(const QString &s); void setBusy(bool b); void setError(const QString &e);
    QString computeBaseName() const;

    QString m_archivePath,m_destinationPath,m_currentEntry,m_status="empty",m_errorMessage;
    qreal m_progress=0; bool m_busy=false;
    int m_conflictMode=0,m_operationType=0;
    bool m_createParentFolder=true;
    QStringList m_createFiles;
    ArchiveEntryModel *m_model;
    QThread *m_workerThread; ArchiveWorker *m_worker;
    QSettings m_settings;
};
